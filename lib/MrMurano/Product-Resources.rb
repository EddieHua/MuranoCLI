require 'MrMurano/Product'
require 'MrMurano/SyncUpDown'

module MrMurano

  ## Manage the resources on a Product
  #
  # There isn't an okami-shim for most of this, it maps right over to 1P-RPC.
  # Or better stated, that's all okami-shim is.
  class ProductResources < ProductBase
    include SyncUpDown
    include ProductOnePlatformRpcShim

    # Resource Specific details on an Item
    class ResourceItem < Item
      # @return [String] Reasource Identifier, internal use only.
      attr_accessor :rid
      # @return [String] The name of this resource
      attr_accessor :alias
      # @return [String] The format of thie resource.
      attr_accessor :format
    end

    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil

      @itemkey = :rid # this is the key that is the identifier used by murano
    end

    ## Get 1P info about the prodcut
    def info
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[model_rid, {}]
      })
    end

    ## Return a list of the product resources as items
    def list()
      data = info()
      ret = []
      data[:aliases].each do |rid, aliases|
        aliases.each do |al|
          ret << {
            :alias => al,
            :rid => rid
          }
        end
      end

      ret
    end

    ## Fetch data from one resource
    def fetch(rid)
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[rid, {}],
      })
    end

    ## Remove a resource by RID
    def remove(rid)
      do_rpc({:id=>1,
              :procedure=>:drop,
              :arguments=>[rid]
      })
    end

    ## Create a new resource in the prodcut
    def create(alias_id, format=:string)
      raise "Alias cannot be nil" if alias_id.nil?
      # create then map.
      rid = do_rpc({:id=>1,
                  :procedure=>:create,
                  :arguments=>[:dataport,
                               {:format=>format,
                                :name=>alias_id,
                                :retention=>{:count=>1,:duration=>:infinity}
                               }
                              ]
      })
      return rid unless not rid.kind_of?(String) or rid.match(/\p{XDigit}{40}/)

      do_rpc({:id=>1,
              :procedure=>:map,
              :arguments=>[:alias, rid, alias_id]
      })
    end

    ## Upload a resource.
    # this is for SyncUpDown
    # @param modify Bool: True if item exists already and this is changing it
    def upload(src, item, modify)
      if modify then
        # this is usually a format change, which can only be set on create.
        # So delete then create.
        remove(item[:rid])
      end
      r = create(item[:alias], item[:format])
      raise "Create Failed: #{r}" unless r.nil?
    end

    ## Use alias for doing sync compares
    # (The RID will change if destroyed and recreated.)
    def synckey(item)
      item[:alias]
    end

    ##
    #
    def tolocalpath(into, item)
      into
    end

    ## Get a local list of items from the single file
    def localitems(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      debug "#{self.class.to_s}: Getting local items from: #{from}"
      if not from.exist? then
        warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        warning "Cannot read from #{from.to_s}"
        return []
      end

      here = []
      from.open {|io| here = YAML.load(io) }
      return [] if here == false

      if here.kind_of?(Hash) and here.has_key?('resources') then
        here['resources'].map{|i| Hash.transform_keys_to_symbols(i)}
      else
        warning "Unexpected data in #{from.to_s}"
        []
      end
    end

    def download(local, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      data = fetch(item[:rid])
      item[:format] = data[:description][:format]

      here = []
      if local.exist? then
        local.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
        if here.kind_of?(Hash) and here.has_key?('resources') then
          here = here['resources'].map{|i| Hash.transform_keys_to_symbols(i)}
        else
          here = []
        end
      end
      here.delete_if do |i|
        i[:alias] == item[:alias]
      end
      here << item.reject{|k,v| k==:synckey or k==:rid}
      here.map!{|i| Hash.transform_keys_to_strings(i)}
      local.dirname.mkpath
      local.open('wb') do |io|
        io << {'resources'=>here}.to_yaml
      end
    end

    def removelocal(dest, item)
      # needs to append/merge with file
      # for now, we'll read, modify, write
      here = []
      if dest.exist? then
        dest.open('rb') {|io| here = YAML.load(io)}
        here = [] if here == false
        if here.kind_of?(Hash) and here.has_key?('resources') then
          here = here['resources'].map{|i| Hash.transform_keys_to_symbols(i)}
        else
          here = []
        end
      end
      here.delete_if do |it|
        it[:alias] == item[:alias]
      end
      here.map!{|i| Hash.transform_keys_to_strings(i)}
      dest.open('wb') do|io|
        io << {'resources'=>here}.to_yaml
      end
    end

    ##
    # True if itemA and itemB are different
    def docmp(itemA, itemB)
      itemA[:alias] != itemB[:alias] or itemA[:format] != itemB[:format]
    end

  end
  #SyncRoot.add('specs', ProductResources, 'P', %{Product Specification})

end
#  vim: set ai et sw=2 ts=2 :
