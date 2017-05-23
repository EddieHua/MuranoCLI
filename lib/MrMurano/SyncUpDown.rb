require 'pathname'
require 'tempfile'
require 'shellwords'
require 'open3'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require 'MrMurano/hash'

module MrMurano
  ## Track what things are syncable.
  class SyncRoot
    # A thing that is syncable.
    Syncable = Struct.new(:name, :class, :type, :desc, :bydefault) do
    end

    ##
    # Add a new entry to syncable things
    # @param name [String] The name to use for the long option
    # @param klass [Class] The class to instanciate from
    # @param type [String] Single letter for short option and status listing
    # @param desc [String] Summary of what this syncs.
    # @param bydefault [Boolean] Is this part of the default sync group
    #
    # @return [nil]
    def self.add(name, klass, type, desc, bydefault=false)
      @@syncset = [] unless defined?(@@syncset)
      @@syncset << Syncable.new(name.to_s, klass, type, desc, bydefault)
      nil
    end

    ##
    # Remove all syncables.
    def self.reset()
      @@syncset = []
    end

    ##
    # Get the list of default syncables.
    # @return [Array<String>] array of names
    def self.bydefault
      @@syncset.select{|a| a.bydefault }.map{|a| a.name}
    end

    ##
    # Iterate over all syncables
    # @param block code to run on each
    def self.each(&block)
      @@syncset.each{|a| yield a.name, a.type, a.class }
    end

    ##
    # Iterate over all syncables with option arguments.
    # @param block code to run on each
    def self.each_option(&block)
      @@syncset.each{|a| yield "-#{a.type.downcase}", "--[no-]#{a.name}", a.desc}
    end

    ##
    # Iterate over just the selected syncables.
    # @param opt [Hash{Symbol=>Boolean}] Options hash of which to select from
    # @param block code to run on each
    def self.each_filtered(opt, &block)
      self.checkSAME(opt)
      @@syncset.each do |a|
        if opt[a.name.to_sym] or opt[a.type.to_sym] then
          yield a.name, a.type, a.class
        end
      end
    end

    ## Adjust options based on all or none
    # If none are selected, select the bydefault ones.
    #
    # @param opt [Hash{Symbol=>Boolean}] Options hash of which to select from
    #
    # @return [nil]
    def self.checkSAME(opt)
      if opt[:all] then
        @@syncset.each {|a| opt[a.name.to_sym] = true }
      else
        any = @@syncset.select {|a| opt[a.name.to_sym] or opt[a.type.to_sym]}
        if any.empty? then
          bydef = $cfg['sync.bydefault'].split
          @@syncset.select{|a| bydef.include? a.name }.each{|a| opt[a.name.to_sym] = true}
        end
      end

      nil
    end
  end

  ## The functionality of a Syncable thing.
  #
  # This provides the logic for computing what things have changed, and pushing and
  # pulling those things.
  #
  module SyncUpDown

    # This is one item that can be synced
    class Item
      # @return [String] The name of this item
      attr_accessor :name
      # @return [Pathname] Where this item lives
      attr_accessor :local_path
      # ??? what is this?
      attr_accessor :id
      # @return [String] The lua code for this item. (not all items use this.)
      attr_accessor :script
      # @return [Integer] The line in #local_path where this #script starts
      attr_accessor :line
      # @return [Integer] The line in #local_path where this #script ends
      attr_accessor :line_end
      # @return [String] If requested, the diff output
      attr_accessor :diff
      # @return [Boolean] When filtering, did this item pass.
      attr_accessor :selected
      # ???? what is this?
      attr_accessor :synckey

      # Initialize a new Item with a few, or all, attributes.
      # @param hsh [Hash{Symbol=>Object}, Item] Initial values
      #
      # @example Initializing with a Hash
      #  Item.new(:name=>'Bob', :local_path => Pathname.new(…))
      # @example Initializing with an Item
      #  item = Item.new(:name => 'get')
      #  Item.new(item)
      def initialize(hsh={})
        hsh.each_pair{|k,v| self[k] = v}
      end

      def as_inst(key)
        return key if key.to_s[0] == '@'
        return "@#{key}"
      end
      private :as_inst
      def as_sym(key)
        return key.to_sym if key.to_s[0] != '@'
        return key.to_s[1..-1].to_sym
      end
      private :as_sym

      # Get attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def [](key)
        public_send(key.to_sym)
      end

      # Set attribute as if this was a Hash
      # @param key [String,Symbol] attribute name
      # @param value [Object] value to set
      def []=(key,value)
        public_send("#{key}=", value)
      end

      # Delete a key
      # @param key [String,Symbol] attribute name
      # @return [Object] The value
      def delete(key)
        inst = as_inst(key)
        remove_instance_variable(inst) if instance_variable_defined?(inst)
      end

      # @return [Hash{Symbol=>Object}] A hash that represents this Item
      def to_h
        Hash[ instance_variables.map{|k| [ as_sym(k), instance_variable_get(k)]} ]
      end

      # Adds the contents of item to self.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] ourself
      def merge!(item)
        item.each_pair{|k,v| self[k] = v}
        self
      end

      # A new Item containing our plus items.
      # @param item [Item,Hash] Stuff to merge
      # @return [Item] New item with contents of both
      def merge(item)
        dup.merge!(item)
      end

      # Calls block once for each non-nil key
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @return [Item]
      def each_pair(&block)
        instance_variables.each do |key|
          yield as_sym(key), instance_variable_get(key)
        end
        self
      end

      # Delete items in self that block returns true.
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] Ourself.
      def reject!(&block)
        instance_variables.each do |key|
          drop = yield as_sym(key), instance_variable_get(key)
          delete(key) if drop
        end
        self
      end

      # A new Item with keys deleted where block is true
      # @yieldparam key [Symbol] The name of the key
      # @yieldparam value [Object] The value for that key
      # @yieldreturn [Boolean] True to delete this key
      # @return [Item] New Item with keys deleted
      def reject(&block)
        dup.reject!(&block)
      end

      # For unit testing.
      include Comparable
      def <=>(anOther)
        self.to_h <=> anOther.to_h
      end
    end

    #######################################################################
    # Methods that must be overridden

    ##
    # Get a list of remote items.
    #
    # Children objects Must override this
    #
    # @return [Array] of Hashes of item details
    def list()
      []
    end

    ## Remove remote item
    #
    # Children objects Must override this
    #
    # @param itemkey [String] The identifying key for this item
    def remove(itemkey)
      # :nocov:
      raise "Forgotten implementation"
      # :nocov:
    end

    ## Upload local item to remote
    #
    # Children objects Must override this
    #
    # @param src [Pathname] Full path of where to upload from
    # @param item [Hash] The item details to upload
    # @param modify [Bool] True if item exists already and this is changing it
    def upload(src, item, modify)
      # :nocov:
      raise "Forgotten implementation"
      # :nocov:
    end

    ##
    # True if itemA and itemB are different
    #
    # Children objects must override this
    #
    def docmp(itemA, itemB)
      true
    end

    #
    #######################################################################

    #######################################################################
    # Methods that could be overriden

    ##
    # Compute a remote item hash from the local path
    #
    # Children objects should override this.
    #
    # @param root [Pathname,String] Root path for this resource type from config files
    # @param path [Pathname,String] Path to local item
    # @return [Item] hash of the details for the remote item for this path
    def toRemoteItem(root, path)
      # This mess brought to you by Windows short path names.
      path = Dir.glob(path.to_s).first
      root = Dir.glob(root.to_s).first
      path = Pathname.new(path)
      root = Pathname.new(root)
      Item.new(:name => path.realpath.relative_path_from(root.realpath).to_s)
    end

    ##
    # Compute the local name from remote item details
    #
    # Children objects should override this or #tolocalpath
    #
    # @param item [Item] listing details for the item.
    # @param itemkey [Symbol] Key for look up.
    def tolocalname(item, itemkey)
      item[itemkey].to_s
    end

    ##
    # Compute the local path from the listing details
    #
    # If there is already a matching local item, some of its details are also in
    # the item hash.
    #
    # Children objects should override this or #tolocalname
    #
    # @param into [Pathname] Root path for this resource type from config files
    # @param item [Item] listing details for the item.
    # @return [Pathname] path to save (or merge) remote item into
    def tolocalpath(into, item)
      return item[:local_path] unless item.local_path.nil?
      itemkey = @itemkey.to_sym
      name = tolocalname(item, itemkey)
      raise "Bad key(#{itemkey}) for #{item}" if name.nil?
      name = Pathname.new(name) unless name.kind_of? Pathname
      name = name.relative_path_from(Pathname.new('/')) if name.absolute?
      into + name
    end

    ## Does item match pattern?
    #
    # Children objects should override this if synckey is not @itemkey
    #
    # Check child specific patterns against item
    #
    # @param item [Item] Item to be checked
    # @param pattern [String] pattern to check with
    # @return [Bool] true or false
    def match(item, pattern)
      false
    end

    ## Get the key used to quickly compare two items
    #
    # Children objects should override this if synckey is not @itemkey
    #
    # @param item [Item] The item to get a key from
    # @return [Object] The object to use a comparison key
    def synckey(item)
      key = @itemkey.to_sym
      item[key]
    end

    ## Download an item into local
    #
    # Children objects should override this or implement #fetch()
    #
    # @param local [Pathname] Full path of where to download to
    # @param item [Item] The item to download
    def download(local, item)
#      if item[:bundled] then
#        warning "Not downloading into bundled item #{synckey(item)}"
#        return
#      end
      local.dirname.mkpath
      id = item[@itemkey.to_sym]
      if id.nil? then
        debug "!!! Missing '#{@itemkey}', using :id instead!"
        debug ":id => #{item[:id]}"
        id = item[:id]
        raise "Both #{@itemkey} and id in item are nil!" if id.nil?
      end
      local.open('wb') do |io|
        fetch(id) do |chunk|
          io.write chunk
        end
      end
    end

    ## Remove local reference of item
    #
    # Children objects should override this if move than just unlinking the local
    # item.
    #
    # @param dest [Pathname] Full path of item to be removed
    # @param item [Item] Full details of item to be removed
    def removelocal(dest, item)
      dest.unlink
    end

    #
    #######################################################################


    # So, for bundles this needs to look at all the places and build up the merged
    # stack of local items.
    #
    # Which means it needs the from to be split into the base and the sub so we can
    # inject bundle directories.

    ##
    # Get a list of local items.
    #
    # Children should never need to override this.  Instead they should override
    # #localitems
    #
    # This collects items in the project and all bundles.
    # @return [Array<Item>] items found
    def locallist()
      # so. if @locationbase/bundles exists
      #  gather and merge: @locationbase/bundles/*/@location
      # then merge @locationbase/@location
      #

#      bundleDir = $cfg['location.bundles'] or 'bundles'
#      bundleDir = 'bundles' if bundleDir.nil?
      items = {}
#      if (@locationbase + bundleDir).directory? then
#        (@locationbase + bundleDir).children.sort.each do |bndl|
#          if (bndl + @location).exist? then
#            verbose("Loading from bundle #{bndl.basename}")
#            bitems = localitems(bndl + @location)
#            bitems.map!{|b| b[:bundled] = true; b} # mark items from bundles.
#
#
#            # use synckey for quicker merging.
#            bitems.each { |b| items[synckey(b)] = b }
#          end
#        end
#      end
      if location.exist? then
        bitems = localitems(location)
        # use synckey for quicker merging.
        bitems.each { |b| items[synckey(b)] = b }
      else
        warning "Skipping missing location #{location}"
      end

      items.values
    end

    ##
    # Get the full path for the local versions
    # @return [Pathname] Location for local items
    def location
      raise "Missing @project_section" if @project_section.nil?
      Pathname.new($cfg['location.base']) + $project["#{@project_section}.location"]
    end

    ##
    # Returns array of globs to search for files
    # @return [Array<String>] of Strings that are globs
    def searchFor
      raise "Missing @project_section" if @project_section.nil?
      $project["#{@project_section}.include"]
    end

    ## Returns array of globs of files to ignore
    # @return [Array<String>] of Strings that are globs
    def ignoring
      raise "Missing @project_section" if @project_section.nil?
      $project["#{@project_section}.exclude"]
    end

    ##
    # Get a list of local items rooted at #from
    #
    # Children rarely need to override this. Only when the locallist is not a set
    # of files in a directory will they need to override it.
    #
    # @param from [Pathname] Directory of items to scan
    # @return [Array<Item>] Items found
    def localitems(from)
      # TODO: Profile this.
      debug "#{self.class.to_s}: Getting local items from: #{from}"
      searchIn = from.to_s
      sf = searchFor.map{|i| ::File.join(searchIn, i)}
      debug "#{self.class.to_s}: Globs: #{sf}"
      Dir[*sf].flatten.compact.reject do |p|
        ::File.directory?(p) or ignoring.any? do |i|
          ::File.fnmatch(i,p)
        end
      end.map do |path|
        path = Pathname.new(path).realpath
        item = toRemoteItem(from, path)
        if item.kind_of?(Array) then
          item.compact.map{|i| i[:local_path] = path; i}
        elsif not item.nil? then
          item[:local_path] = path
          item
        end
      end.flatten.compact
    end

    #######################################################################
    # Methods that provide the core status/syncup/syncdown

    ##
    # Take a hash or something (a Commander::Command::Options) and return a hash
    #
    # @param hsh [Hash, Commander::Command::Options] Thing we want to be a Hash
    # @return [Hash] an actual Hash with default value of false
    def elevate_hash(hsh)
      # Commander::Command::Options stripped all of the methods from parent
      # objects. I have not nice thoughts about that.
      begin
        hsh = hsh.__hash__
      rescue NoMethodError
        # swallow this.
      end
      # build a hash where the default is 'false' instead of 'nil'
      Hash.new(false).merge(Hash.transform_keys_to_symbols(hsh))
    end
    private :elevate_hash

    ## Make things in Murano look like local project
    #
    # This creates, uploads, and deletes things as needed up in Murano to match
    # what is in the local project directory.
    #
    # @param options [Hash, Commander::Command::Options] Options on opertation
    # @param selected [Array<String>] Filters for _matcher
    def syncup(options={}, selected=[])
      options = elevate_hash(options)
      itemkey = @itemkey.to_sym
      options[:asdown] = false
      dt = status(options, selected)
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options[:delete] then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            remove(item[itemkey])
          end
        end
      end
      if options[:create] then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path}, false)
          end
        end
      end
      if options[:update] then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            upload(item[:local_path], item.reject{|k,v| k==:local_path}, true)
          end
        end
      end
    end

    ## Make things in local project look like Murano
    #
    # This creates, downloads, and deletes things as needed up in the local project
    # directory to match what is in Murano.
    #
    # @param options [Hash, Commander::Command::Options] Options on opertation
    # @param selected [Array<String>] Filters for _matcher
    def syncdown(options={}, selected=[])
      options = elevate_hash(options)
      options[:asdown] = true
      dt = status(options, selected)
      into = location ###
      toadd = dt[:toadd]
      todel = dt[:todel]
      tomod = dt[:tomod]

      if options[:delete] then
        todel.each do |item|
          verbose "Removing item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            removelocal(dest, item)
          end
        end
      end
      if options[:create] then
        toadd.each do |item|
          verbose "Adding item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
      if options[:update] then
        tomod.each do |item|
          verbose "Updating item #{item[:synckey]}"
          unless $cfg['tool.dry'] then
            dest = tolocalpath(into, item)
            download(dest, item)
          end
        end
      end
    end

    ## Call external diff tool on item
    #
    # WARNING: This will download the remote item to do the diff.
    #
    # @param item [Item] The item to get a diff of
    # @return [String] The diff output
    def dodiff(item)
      trmt = Tempfile.new([tolocalname(item, @itemkey)+'_remote_', '.lua'])
      tlcl = Tempfile.new([tolocalname(item, @itemkey)+'_local_', '.lua'])
      if item.has_key? :script then
        Pathname.new(tlcl.path).open('wb') do |io|
          io << item[:script]
        end
      else
        Pathname.new(tlcl.path).open('wb') do |io|
          io << item[:local_path].read
        end
      end
      df = ""
      begin
        download(Pathname.new(trmt.path), item)

        cmd = $cfg['diff.cmd'].shellsplit
        cmd << trmt.path.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR)
        cmd << tlcl.path.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR || ::File::SEPARATOR)

        df, _ = Open3.capture2e(*cmd)
      ensure
        trmt.close
        trmt.unlink
        tlcl.close
        tlcl.unlink
      end
      df
    end

    ##
    # Check if an item matches a pattern.
    # @param items [Array<Item>] Of items to filter
    # @param patterns [Array<String>] Filters for _matcher
    def _matcher(items, patterns)
      items.map do |item|
        if patterns.empty? then
          item[:selected] = true
        else
          item[:selected] = patterns.any? do |pattern|
            if pattern.to_s[0] == '#' then
              match(item, pattern)
            elsif item.local_path.nil? then
              false
            else
              item[:local_path].fnmatch(pattern)
            end
          end
        end
        item
      end
    end
    private :_matcher

    ## Get status of things here verses there
    #
    # @param options [Hash, Commander::Command::Options] Options on operation
    # @param selected [Array<String>] Filters for _matcher
    # @return [Hash{Symbol=>Array<Item>}] Items grouped by the action that should be taken
    def status(options={}, selected=[])
      options = elevate_hash(options)
      itemkey = @itemkey.to_sym

      there = _matcher(list(), selected)     # Array<Item>
      here = _matcher(locallist(), selected) # Array<Item>

      therebox = {}
      there.each do |item|
        item[:synckey] = synckey(item)
        therebox[ item[:synckey] ] = item
      end
      herebox = {}
      here.each do |item|
        item[:synckey] = synckey(item)
        herebox[ item[:synckey] ] = item
      end
      toadd = []
      todel = []
      tomod = []
      unchg = []
      if options[:asdown] then
        todel = (herebox.keys - therebox.keys).map{|key| herebox[key] }
        toadd = (therebox.keys - herebox.keys).map{|key| therebox[key] }
      else
        toadd = (herebox.keys - therebox.keys).map{|key| herebox[key] }
        todel = (therebox.keys - herebox.keys).map{|key| therebox[key] }
      end
      (herebox.keys & therebox.keys).each do |key|
        # Want here to override there except for itemkey.
        mrg = herebox[key].reject{|k,v| k==itemkey}
        mrg = therebox[key].merge(mrg)
        if docmp(herebox[key], therebox[key]) then
          mrg[:diff] = dodiff(mrg.to_h) if options[:diff] and mrg[:selected]
          tomod << mrg
        else
          unchg << mrg
        end
      end
      if options[:unselected] then
        { :toadd=>toadd, :todel=>todel, :tomod=>tomod, :unchg=>unchg }
      else
        {
          :toadd=>toadd.select{|i| i[:selected]}.map{|i| i.delete(:selected); i},
          :todel=>todel.select{|i| i[:selected]}.map{|i| i.delete(:selected); i},
          :tomod=>tomod.select{|i| i[:selected]}.map{|i| i.delete(:selected); i},
          :unchg=>unchg.select{|i| i[:selected]}.map{|i| i.delete(:selected); i}
        }
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
