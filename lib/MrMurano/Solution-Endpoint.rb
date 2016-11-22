require 'uri'
require 'net/http'
require 'json'
require 'pp'
require 'MrMurano/Solution'

module MrMurano
  # …/endpoint
  class Endpoint < SolutionBase
    def initialize
      super
      @uriparts << 'endpoint'
      @location = $cfg['location.endpoints']
    end

    ##
    # This gets all data about all endpoints
    def list
      get().map do |item|
        item[:content_type] = 'application/json' if item[:content_type].empty?
        item
      end
    end

    def fetch(id)
      ret = get('/' + id.to_s)
      ret[:content_type] = 'application/json' if ret[:content_type].empty?
      # TODO: add content_type to header if not application/json
      aheader = (ret[:script].lines.first or "").chomp
      dheader = /^--#ENDPOINT (?i:#{ret[:method]}) #{ret[:path]}$/
      rheader = %{--#ENDPOINT #{ret[:method].upcase} #{ret[:path]}\n}
      if block_given? then
        yield rheader unless dheader =~ aheader
        yield ret[:script]
      else
        res = ''
        res << rheader unless dheader =~ aheader
        res << ret[:script]
        res
      end
    end

    ##
    # Upload endpoint
    # :local path to file to push
    # :remote hash of method and endpoint path
    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify)
      local = Pathname.new(local) unless local.kind_of? Pathname
      raise "no file" unless local.exist?

      # we assume these are small enough to slurp.
      unless remote.has_key? :script then
        script = local.read
        remote[:script] = script
      end
      limitkeys = [:method, :path, :script, :content_type, @itemkey]
      remote = remote.select{|k,v| limitkeys.include? k }
#      post('', remote)
      if remote.has_key? @itemkey then
        put('/' + remote[@itemkey], remote) do |request, http|
          response = http.request(request)
          case response
          when Net::HTTPSuccess
            #return JSON.parse(response.body)
          when Net::HTTPNotFound
            verbose "\tDoesn't exist, creating"
            post('/', remote)
          else
            showHttpError(request, response)
          end
        end
      else
        verbose "\tNo itemkey, creating"
        post('/', remote)
      end
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/' + id.to_s)
    end

    def tolocalname(item, key)
      name = ''
      name << item[:path].split('/').reject{|i|i.empty?}.join('-')
      name << '.'
      name << item[:method].downcase
      name << '.lua'
    end

    def toRemoteItem(from, path)
      # Path could be have multiple endpoints in side, so a loop.
      items = []
      path = Pathname.new(path) unless path.kind_of? Pathname
      cur = nil
      lineno=0
      path.readlines().each do |line|
        md = /--#ENDPOINT (?<method>\S+) (?<path>\S+)( (?<ctype>.*))?/.match(line)
        if not md.nil? then
          # header line.
          cur[:line_end] = lineno unless cur.nil?
          items << cur unless cur.nil?
          cur = {:method=>md[:method],
                 :path=>md[:path],
                 :content_type=> (md[:ctype] or 'application/json'),
                 :local_path=>path,
                 :line=>lineno,
                 :script=>line}
        elsif not cur.nil? and not cur[:script].nil? then
          cur[:script] << line
        end
        lineno += 1
      end
      cur[:line_end] = lineno unless cur.nil?
      items << cur unless cur.nil?
      items
    end

    def synckey(item)
      "#{item[:method].upcase}_#{item[:path]}"
    end

    def docmp(itemA, itemB)
      if itemA[:script].nil? and itemA[:local_path] then
        itemA[:script] = itemA[:local_path].read
      end
      if itemB[:script].nil? and itemB[:local_path] then
        itemB[:script] = itemB[:local_path].read
      end
      return (itemA[:script] != itemB[:script] or itemA[:content_type] != itemB[:content_type])
    end

  end

  SyncRoot.add('endpoints', Endpoint, 'A', %{Endpoints}, true)
end
#  vim: set ai et sw=2 ts=2 :
