require 'uri'
require 'net/http'
require 'json'
require 'pp'
require 'MrMurano/Webservice'

module MrMurano
  # …/endpoint
  module Webservice
    class Endpoint < Base
      def initialize
        super
        @uriparts << 'endpoint'
        @project_section = :routes

        @match_header = /--#ENDPOINT (?<method>\S+) (?<path>\S+)( (?<ctype>.*))?/
      end

      ##
      # This gets all data about all endpoints
      def list
        get().map do |item|
          if item[:content_type].nil? or item[:content_type].empty? then
            item[:content_type] = 'application/json'
          end
          # XXX should this update the script header?
          item
        end
      end

      def fetch(id)
        ret = get('/' + id.to_s)
        ret[:content_type] = 'application/json' if ret[:content_type].empty?

        script = ret[:script].lines.map{|l|l.chomp}

        aheader = (script.first or "")

        rh = ['--#ENDPOINT', ret[:method].upcase, ret[:path]]
        rh << ret[:content_type] if ret[:content_type] != 'application/json'
        rheader = rh.join(' ')

        # if header is missing add it.
        # If header is wrong, replace it.

        md = @match_header.match(aheader)
        if md.nil? then
          # header missing.
          script.unshift rheader
        elsif md[:method] != ret[:method] or
              md[:path] != ret[:path] or
              md[:ctype] != ret[:content_type] then
          # header is wrong.
          script[0] = rheader
        end
        # otherwise current header is good.

        script = script.join("\n") + "\n"
        if block_given? then
          yield script
        else
          script
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
          md = @match_header.match(line)
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

      def match(item, pattern)
        # Pattern is: #{method}#{path glob}
        pattern_pattern = /^#(?<method>[^#]*)#(?<path>.*)/i
        md = pattern_pattern.match(pattern)
        return false if md.nil?
        debug "match pattern: '#{md[:method]}' '#{md[:path]}'"

        unless md[:method].empty? then
          return false unless item[:method].downcase == md[:method].downcase
        end

        return true if md[:path].empty?

        ::File.fnmatch(md[:path],item[:path])
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
end
#  vim: set ai et sw=2 ts=2 :
