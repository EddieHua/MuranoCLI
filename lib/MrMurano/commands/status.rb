
command :status do |c|
  c.syntax = %{murano status [options] [filters]}
  c.summary = %{Get the status of files}
  c.description = %{Get the status of files

  Compares the local project against what is up in Murano, returning a summary of
  what things are new or changed.

  When --diff is passed, for items that have changes, the remote item and local
  item are passed to a diff tool and that output is included.

  The diff tool and options to it can be set with the config key 'diff.cmd'.


  Filters allow for selecting a subset of items to check based on patterns.

  File glob filters can be used to select local files.  The glob is compared with
  the full file path.

  Each item type also supports specific filters. These always start with #.
  Endpoints can be selected with a "#<method>#<path glob>" pattern.


  }.gsub(/^ +/,'')
  c.option '--all', 'Check everything'

  # Load options to control which things to status
  MrMurano::SyncRoot.each_option do |s,l,d|
    c.option s, l, d
  end

  c.option '--[no-]asdown', %{Report as if syncdown instead of syncup}
  c.option '--[no-]diff', %{For modified items, show a diff}
  c.option '--[no-]grouped', %{Group all adds, deletes, and mods together}
  c.option '--[no-]showall', %{List unchanged as well}

  c.action do |args,options|
    options.default :delete=>true, :create=>true, :update=>true, :diff=>false,
      :grouped => true

    def fmtr(item)
      if item.has_key? :local_path then
        lp = item[:local_path].relative_path_from(Pathname.pwd()).to_s
        if item.has_key?(:line) and item[:line] > 0 then
          return "#{lp}:#{item[:line]}"
        end
        lp
      else
        item[:synckey]
      end
    end
    def pretty(ret, options)
      say "Adding:" if options.grouped
      ret[:toadd].each{|item| say " + #{item[:pp_type]}  #{fmtr(item)}"}
      say "Deleteing:" if options.grouped
      ret[:todel].each{|item| say " - #{item[:pp_type]}  #{fmtr(item)}"}
      say "Changing:" if options.grouped
      ret[:tomod].each{|item|
        say " M #{item[:pp_type]}  #{fmtr(item)}"
        say item[:diff] if options.diff
      }
      if options.showall then
        say "Unchanged:" if options.grouped
        ret[:unchg].each{|item| say "   #{item[:pp_type]}  #{fmtr(item)}"}
      end
    end

    @grouped = {:toadd=>[],:todel=>[],:tomod=>[], :unchg=>[]}
    def gmerge(ret, type, options)
      if options.grouped then
        out = @grouped
      else
        out = {:toadd=>[],:todel=>[],:tomod=>[], :unchg=>[]}
      end

      [:toadd, :todel, :tomod, :unchg].each do |kind|
        ret[kind].each do |item|
          item = item.to_h
          item[:pp_type] = type
          out[kind] << item
        end
      end

      unless options.grouped then
        pretty(out, options)
      end
    end

    MrMurano::SyncRoot.each_filtered(options.__hash__) do |name, type, klass|
      sol = klass.new
      ret = sol.status(options, args)
      gmerge(ret, type, options)
    end

    pretty(@grouped, options) if options.grouped
  end
end

alias_command :diff, :status, '--diff', '--no-grouped'

#  vim: set ai et sw=2 ts=2 :
