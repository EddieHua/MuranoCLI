require 'pathname'
require 'inifile'
require 'highline'

module MrMurano
  class Config
    #
    #  internal    transient this-run-only things (also -c options)
    #  specified   from --configfile
    #  env         from ENV['MURANO_CONFIGFILE']
    #  project     .murano/config at project dir
    #  user        .murano/config at $HOME
    #  defaults    Internal hardcoded defaults
    #
    ConfigFile = Struct.new(:kind, :path, :data) do
      def load()
        return if kind == :internal
        return if kind == :defaults
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].restore
      end

      def write()
        return if kind == :internal
        return if kind == :defaults
        self[:path] = Pathname.new(path) unless path.kind_of? Pathname
        self[:data] = IniFile.new(:filename=>path.to_s) if self[:data].nil?
        self[:data].save
        path.chmod(0600)
      end
    end

    attr :paths
    attr_reader :projectDir

    CFG_SCOPES=%w{internal specified env project user defaults}.map{|i| i.to_sym}.freeze

    CFG_ENV_NAME=%{MURANO_CONFIGFILE}.freeze
    CFG_FILE_NAME=%[.murano/config].freeze
    CFG_DIR_NAME=%[.murano].freeze

    CFG_OLD_ENV_NAME=%[MR_CONFIGFILE].freeze
    CFG_OLD_DIR_NAME=%[.mrmurano].freeze
    CFG_OLD_FILE_NAME=%[.mrmuranorc].freeze

    def warning(msg)
      $stderr.puts HighLine.color(msg, :yellow)
    end
    def error(msg)
      $stderr.puts HighLine.color(msg, :red)
    end

    def migrateOldEnv
      unless ENV[CFG_OLD_ENV_NAME].nil? then
        warning %{ENV "#{CFG_OLD_ENV_NAME}" is no longer supported. Rename it to "#{CFG_ENV_NAME}"}
        unless ENV[CFG_ENV_NAME].nil? then
          error %{Both "#{CFG_ENV_NAME}" and "#{CFG_OLD_ENV_NAME}" defined, please remove "#{CFG_OLD_ENV_NAME}".}
        end
        ENV[CFG_ENV_NAME] = ENV[CFG_OLD_ENV_NAME]
      end
    end

    def migrateOldConfig(where)
      # Check for dir.
      if (where + CFG_OLD_DIR_NAME).exist? then
        warning %{Moving old directory "#{CFG_OLD_DIR_NAME}" to "#{CFG_DIR_NAME}" in "#{where}"}
        (where + CFG_OLD_DIR_NAME).rename(where + CFG_DIR_NAME)
      end

      # check for cfg.
      if (where + CFG_OLD_FILE_NAME).exist? then
        warning %{Moving old config "#{CFG_OLD_FILE_NAME}" to "#{CFG_FILE_NAME}" in "#{where}"}
        (where + CFG_DIR_NAME).mkpath
        (where + CFG_OLD_FILE_NAME).rename(where + CFG_FILE_NAME)
      end
    end

    def initialize
      @paths = []
      @paths << ConfigFile.new(:internal, nil, IniFile.new())
      # :specified --configfile FILE goes here. (see load_specific)

      migrateOldEnv
      unless ENV[CFG_ENV_NAME].nil? then
        # if it exists, must be a file
        # if it doesn't exist, that's ok
        ep = Pathname.new(ENV[CFG_ENV_NAME])
        if ep.file? or not ep.exist? then
          @paths << ConfigFile.new(:env, ep)
        end
      end

      @projectDir = findProjectDir()
      migrateOldConfig(@projectDir)
      @paths << ConfigFile.new(:project,  @projectDir + CFG_FILE_NAME)
      (@projectDir + CFG_DIR_NAME).mkpath
      fixModes(@projectDir + CFG_DIR_NAME)

      migrateOldConfig(Pathname.new(Dir.home))
      @paths << ConfigFile.new(:user, Pathname.new(Dir.home) + CFG_FILE_NAME)
      (Pathname.new(Dir.home) + CFG_DIR_NAME).mkpath
      fixModes(Pathname.new(Dir.home) + CFG_DIR_NAME)

      @paths << ConfigFile.new(:defaults, nil, IniFile.new())


      set('tool.verbose', false, :defaults)
      set('tool.debug', false, :defaults)
      set('tool.dry', false, :defaults)
      set('tool.fullerror', false, :defaults)
      set('tool.outformat', 'best', :defaults)
      set('tool.1p_legacy', false, :defaults)

      set('net.host', 'bizapi.hosted.exosite.io', :defaults)

      set('location.base', @projectDir, :defaults) unless @projectDir.nil?
      set('location.files', 'files', :defaults)
      set('location.endpoints', 'routes', :defaults)
      set('location.modules', 'modules', :defaults)
      set('location.eventhandlers', 'services', :defaults)
      set('location.resources', 'specs/resources.yaml', :defaults)
      set('location.cors', 'cors.yaml', :defaults)

      set('sync.bydefault', SyncRoot.bydefault.join(' '), :defaults) if defined? SyncRoot

      set('files.default_page', 'index.html', :defaults)
      set('files.searchFor', '**/*', :defaults)
      set('files.ignoring', '', :defaults)

      set('endpoints.searchFor', '{,../endpoints}/*.lua {,../endpoints}s/*/*.lua', :defaults)
      set('endpoints.ignoring', '*_test.lua *_spec.lua .*', :defaults)

      set('eventhandler.searchFor', '*.lua */*.lua {../eventhandlers,../event_handler}/*.lua {../eventhandlers,../event_handler}/*/*.lua', :defaults)
      set('eventhandler.ignoring', '*_test.lua *_spec.lua .*', :defaults)
      set('eventhandler.skiplist', 'websocket webservice device.service_call', :defaults)

      set('modules.searchFor', '*.lua */*.lua', :defaults)
      set('modules.ignoring', '*_test.lua *_spec.lua .*', :defaults)

      if Gem.win_platform? then
        set('diff.cmd', 'fc', :defaults)
      else
        set('diff.cmd', 'diff -u', :defaults)
      end
    end

    ## Find the root of this project Directory.
    #
    # The Project dir is the directory between PWD and HOME that has one of (in
    # order of preference):
    # - .murano/config
    # - .mrmuranorc
    # - .murano/
    # - .mrmurano/
    def findProjectDir()
      result=nil
      fileNames=[CFG_FILE_NAME, CFG_OLD_FILE_NAME]
      dirNames=[CFG_DIR_NAME, CFG_OLD_DIR_NAME]
      home = Pathname.new(Dir.home).realpath
      pwd = Pathname.new(Dir.pwd).realpath
      return home if home == pwd
      pwd.ascend do |i|
        break unless result.nil?
        break if i == home
        fileNames.each do |f|
          if (i + f).exist? then
            result = i
          end
        end
        dirNames.each do |f|
          if (i + f).directory? then
            result = i
          end
        end
      end

      # Now if nothing found, assume it will live in pwd.
      result = Pathname.new(Dir.pwd) if result.nil?
      return result
    end
    private :findProjectDir

    def fixModes(path)
      if path.directory? then
        path.chmod(0700)
      elsif path.file? then
        path.chmod(0600)
      end
    end

    def file_at(name, scope=:project)
      case scope
      when :internal
        root = nil
      when :specified
        root = nil
      when :project
        root = @projectDir + CFG_DIR_NAME
      when :user
        root = Pathname.new(Dir.home) + CFG_DIR_NAME
      when :defaults
        root = nil
      end
      return nil if root.nil?
      root.mkpath
      root + name
    end

    ## Load all of the potential config files
    def load()
      # - read/write config file in [Project, User, System] (all are optional)
      @paths.each { |cfg| cfg.load }
    end

    ## Load specified file into the config stack
    # This can be called multiple times and each will get loaded into the config
    def load_specific(file)
      spc = ConfigFile.new(:specified, Pathname.new(file))
      spc.load
      @paths.insert(1, spc)
    end

    ## Get a value for key, looking at the specified scopes
    # key is <section>.<key>
    def get(key, scope=CFG_SCOPES)
      scope = [scope] unless scope.kind_of? Array
      paths = @paths.select{|p| scope.include? p.kind}

      section, ikey = key.split('.')
      paths.each do |path|
        if path.data.has_section?(section) then
          sec = path.data[section]
          return sec if ikey.nil?
          if sec.has_key?(ikey) then
            return sec[ikey]
          end
        end
      end
      return nil
    end

    ## Dump out a combined config
    def dump()
      # have a fake, merge all into it, then dump it.
      base = IniFile.new()
      @paths.reverse.each do |ini|
        base.merge! ini.data
      end
      base.to_s
    end

    def set(key, value, scope=:project)
      section, ikey = key.split('.', 2)
      raise "Invalid key" if section.nil?
      if not section.nil? and ikey.nil? then
        # If key isn't dotted, then assume the tool section.
        ikey = section
        section = 'tool'
      end

      paths = @paths.select{|p| scope == p.kind}
      raise "Unknown scope" if paths.empty?
      cfg = paths.first
      data = cfg.data
      tomod = data[section]
      tomod[ikey] = value unless value.nil?
      tomod.delete(ikey) if value.nil?
      data[section] = tomod
      cfg.write
    end

    # key is <section>.<key>
    def [](key)
      get(key)
    end

    # For setting internal, this-run-only values
    def []=(key, value)
      set(key, value, :internal)
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
