require 'uri'
require 'net/http'
require "http/form_data"
require 'digest/sha1'
require 'mime/types'
require 'pp'
require 'MrMurano/Solution'

module MrMurano
  # …/file
  class File < SolutionBase
    # File Specific details on an Item
    class FileItem < Item
      # @return [String] path for URL maps to this static file
      attr_accessor :path
      # @return [String] The MIME-Type for this content
      attr_accessor :mime_type
      # @return [String] Checksum for the content.
      attr_accessor :checksum
    end
    def initialize
      super
      @uriparts << 'file'
      @itemkey = :path
      @project_section = :assets
    end

    ##
    # Get a list of all of the static content
    def list
      ret = get()
      return [] if ret.is_a? Hash and ret.has_key? :error
      ret.map{|i| FileItem.new(i)}
    end

    ##
    # Get one item of the static content.
    def fetch(path, &block)
      path = path[1..-1] if path[0] == '/'
      path = '/'+ URI.encode_www_form_component(path)
      get(path) do |request, http|
        http.request(request) do |resp|
          case resp
          when Net::HTTPSuccess
            if block_given? then
              resp.read_body(&block)
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            showHttpError(request, resp)
          end
        end
        nil
      end
    end

    ##
    # Delete a file
    def remove(path)
      path = path[1..-1] if path[0] == '/'
      delete('/'+ URI.encode_www_form_component(path))
    end

    def curldebug(request)
      # The upload will get printed out inside of upload.
      # Because we don't have the correct info here.
      if request.method != 'PUT' then
        super(request)
      end
    end

    ##
    # Upload a file
    # @param modify Bool: True if item exists already and this is changing it
    def upload(local, remote, modify)
      local = Pathname.new(local) unless local.kind_of? Pathname

      path = remote[:path]
      path = path[1..-1] if path[0] == '/'
      uri = endPoint('upload/' + URI.encode_www_form_component(path))

      # kludge past for a bit.
      #`curl -s -H 'Authorization: token #{@token}' '#{uri.to_s}' -F file=@#{local.to_s}`

      # http://stackoverflow.com/questions/184178/ruby-how-to-post-a-file-via-http-as-multipart-form-data
      #
      # Look at: https://github.com/httprb/http
      # If it works well, consider porting over to it.
      #
      # Or just: https://github.com/httprb/form_data.rb ?
      #
      # Most of these pull into ram.  So maybe just go with that. Would guess that
      # truely large static content is rare, and we can optimize/fix that later.

      file = HTTP::FormData::File.new(local.to_s, {:content_type=>remote[:mime_type]})
      form = HTTP::FormData.create(:file=>file)
      req = Net::HTTP::Put.new(uri)
      set_def_headers(req)
      workit(req) do |request,http|
        request.content_type = form.content_type
        request.content_length = form.content_length
        request.body = form.to_s

        if $cfg['tool.curldebug'] then
          a = []
          a << %{curl -s -H 'Authorization: #{request['authorization']}'}
          a << %{-H 'User-Agent: #{request['User-Agent']}'}
          a << %{-X #{request.method}}
          a << %{'#{request.uri.to_s}'}
          a << %{-F file=@#{local.to_s}}
          puts a.join(' ')
        end

        response = http.request(request)
        case response
        when Net::HTTPSuccess
        else
          showHttpError(request, response)
        end
      end
    end

    def tolocalname(item, key)
      name = item[key]
      name = $cfg['files.default_page'] if name == '/'
      name
    end

    def toRemoteItem(from, path)
      item = super(from, path)
      name = item[:name]
      name = '/' if name == $cfg['files.default_page']
      name = "/#{name}" unless name.chars.first == '/'

      mime = MIME::Types.type_for(path.to_s)[0] || MIME::Types["application/octet-stream"][0]

      # It does not actually take the SHA1 of the file.
      # It first converts the file to hex, then takes the SHA1 of that string
      #sha1 = Digest::SHA1.file(path.to_s).hexdigest
      sha1 = Digest::SHA1.new
      path.open('rb:ASCII-8BIT') do |io|
        while chunk = io.read(1048576) do
          sha1 << Digest.hexencode(chunk)
        end
      end
      debug "Checking #{name} (#{mime.simplified} #{sha1.hexdigest})"

      FileItem.new(:path=>name, :mime_type=>mime.simplified, :checksum=>sha1.hexdigest)
    end

    def synckey(item)
      item[:path]
    end

    def docmp(itemA, itemB)
      return (itemA[:mime_type] != itemB[:mime_type] or
        itemA[:checksum] != itemB[:checksum])
    end

  end
  SyncRoot.add('files', File, 'S', %{Static Files}, true)
end
#  vim: set ai et sw=2 ts=2 :
