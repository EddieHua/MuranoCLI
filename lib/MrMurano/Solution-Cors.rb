require 'yaml'
require 'json'
require 'MrMurano/Solution'

module MrMurano
  class Cors < SolutionBase
    def initialize
      super
      @uriparts << 'cors'
      @location = $cfg['location.cors']
    end

    def list()
      data = fetch()
      data[:id] = 'cors'
      [data]
    end

    def fetch(id=nil, &block)
      ret = get()
      if ret.kind_of?(Hash) and ret.has_key?(:cors) then
        # XXX cors is a JSON encoded string. That seems weird. keep an eye on this.
        data = JSON.parse(ret[:cors], @json_opts)
      else
        data = ret
      end
      if block_given? then
        yield Hash.transform_keys_to_strings(data).to_yaml
      else
        data
      end
    end

    def remove(id)
      # Not really anything to do here. Return to defaults? maybe?
    end

    ##
    # Upload CORS
    # :local path to file to push
    # :remote hash of method and endpoint path (ignored for now)
    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify=false)
      remote.reject!{|k,v| k==:synckey or k==:bundled or k==:id}
      put('', remote)
    end

    def tolocalpath(into, item)
      into
    end

    def removelocal(dest, item)
      # this is a nop.
    end
#
    def localitems(from)
      from = Pathname.new(from) unless from.kind_of? Pathname
      if not from.exist? then
        warning "Skipping missing #{from.to_s}"
        return []
      end
      unless from.file? then
        warning "Cannot read from #{from.to_s}"
        return []
      end

      here = {}
      from.open {|io| here = YAML.load(io) }
      return [] if here == false

      here[:id] = 'cors'
      here[:local_path] = from
      [ Hash.transform_keys_to_symbols(here) ]
    end

    ##
    # True if itemA and itemB are different
    def docmp(itemA, itemB)
      itemA != itemB
    end

  end
  SyncRoot.add('cors', Cors, 'Z', %{CORS settings})
end

#  vim: set ai et sw=2 ts=2 :
