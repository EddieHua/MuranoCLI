require 'date'
require 'uri'
require 'net/http'
require 'json'
require('certified') if Gem.win_platform?

module MrMurano
  module Http
    def token
      return @token unless @token.nil?
      acc = Account.new
      @token = acc.token
      raise "Not logged in!" if @token.nil?
      acc.adc_compat_check
      @token
    end

    def json_opts
      return @json_opts unless not defined?(@json_opts) or @json_opts.nil?
      @json_opts = {
        :allow_nan => true,
        :symbolize_names => true,
        :create_additions => false
      }
    end

    def curldebug(request)
      if $cfg['tool.curldebug'] then
        formp = (request.content_type =~ %r{multipart/form-data})
        a = []
        a << %{curl -s}
        if request.key?('Authorization') then
          a << %{-H 'Authorization: #{request['Authorization']}'}
        end
        a << %{-H 'User-Agent: #{request['User-Agent']}'}
        a << %{-H 'Content-Type: #{request.content_type}'} unless formp
        a << %{-X #{request.method}}
        a << %{'#{request.uri.to_s}'}
        unless request.body.nil? then
          if formp then
            m = request.body.match(%r{form-data;\s+name="(?<name>[^"]+)";\s+filename="(?<filename>[^"]+)"})
            a << %{-F #{m[:name]}=@#{m[:filename]}} unless m.nil?
          else
            a << %{-d '#{request.body}'}
          end
        end
        unless defined?(@@curlfile)
          puts a.join(' ')
        else
          @@curlfile << a.join(' ') + "\n\n"
          @@curlfile.flush
          # MEH: Call @@curlfile.close() at some point?
        end
      end
    end

    ## Open a file for capturing curl calls.
    # Start with the current time and config.
    def self.initCurlfile
      if $cfg['tool.curldebug'] and $cfg['tool.curlfile'] then
        unless defined?(@@curlfile)
          @@curlfile = File.open($cfg['tool.curlfile'], 'a')
          @@curlfile << Time.now << "\n"
          @@curlfile << "murano #{ARGV.join(' ')}\n"
        end
      end
    end

    def http
      uri = URI('https://' + $cfg['net.host'])
      if not defined?(@http) or @http.nil? then
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = true
        @http.start
      end
      @http
    end
    def http_reset
      @http = nil
    end

    def set_def_headers(request)
      request.content_type = 'application/json'
      request['Authorization'] = 'token ' + token
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request
    end

    def isJSON(data)
      begin
        return true, JSON.parse(data, json_opts)
      rescue
        return false, data
      end
    end

    def showHttpError(request, response)
      if $cfg['tool.debug'] then
        puts "Sent #{request.method} #{request.uri.to_s}"
        request.each_capitalized{|k,v| puts "> #{k}: #{v}"}
        if request.body.nil? then
        else
          puts ">> #{request.body[0..156]}"
        end
        puts "Got #{response.code} #{response.message}"
        response.each_capitalized{|k,v| puts "< #{k}: #{v}"}
      end
      isj, jsn = isJSON(response.body)
      resp = "Request Failed: #{response.code}: "
      if isj then
        if $cfg['tool.fullerror'] then
          resp << JSON.pretty_generate(jsn)
        else
          resp << "[#{jsn[:statusCode]}] " if jsn.has_key? :statusCode
          resp << jsn[:message] if jsn.has_key? :message
        end
      else
        resp << (jsn or 'nil')
      end
      # assuming verbosing was included.
      error resp
    end

    def workit(request, &block)
      curldebug(request)
      if block_given? then
        return yield request, http()
      else
        response = http().request(request)
        case response
        when Net::HTTPSuccess
          return {} if response.body.nil?
          begin
            return JSON.parse(response.body, json_opts)
          rescue
            return response.body
          end
        else
          showHttpError(request, response)
        end
      end
    end

    def get(path='', query=nil, &block)
      uri = endPoint(path)
      uri.query = URI.encode_www_form(query) unless query.nil?
      workit(set_def_headers(Net::HTTP::Get.new(uri)), &block)
    end

    def post(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def postf(path='', form={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
      req.form_data = form
      workit(req, &block)
    end

    def put(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Put.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def patch(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Patch.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def delete(path='', &block)
      uri = endPoint(path)
      workit(set_def_headers(Net::HTTP::Delete.new(uri)), &block)
    end

  end
end

# There is a bug were not having TCP_NODELAY set causes connection issues with
# Murano.  While ultimatily the bug is up there, we need to work around it down
# here.  As for Ruby, setting TCP_NODELAY was added in 2.1.  But since the default
# version installed on macos is 2.0.0 we hit it.
#
# So, if the current version of Ruby is 2.0.0, then use this bit of code I copied
# from Ruby 2.1.

if RUBY_VERSION == '2.0.0' then
  module Net
    class HTTP
      def connect
        if proxy? then
          conn_address = proxy_address
          conn_port    = proxy_port
        else
          conn_address = address
          conn_port    = port
        end

        D "opening connection to #{conn_address}:#{conn_port}..."
        s = Timeout.timeout(@open_timeout, Net::OpenTimeout) {
          TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
        }
        s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        D "opened"
        if use_ssl?
          ssl_parameters = Hash.new
          iv_list = instance_variables
          SSL_IVNAMES.each_with_index do |ivname, i|
            if iv_list.include?(ivname) and
                value = instance_variable_get(ivname)
              ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
            end
          end
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.set_params(ssl_parameters)
          D "starting SSL for #{conn_address}:#{conn_port}..."
          s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
          s.sync_close = true
          D "SSL established"
        end
        @socket = BufferedIO.new(s)
        @socket.read_timeout = @read_timeout
        @socket.continue_timeout = @continue_timeout
        @socket.debug_output = @debug_output
        if use_ssl?
          begin
            if proxy?
              buf = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
              buf << "Host: #{@address}:#{@port}\r\n"
              if proxy_user
                credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
                credential.delete!("\r\n")
                buf << "Proxy-Authorization: Basic #{credential}\r\n"
              end
              buf << "\r\n"
              @socket.write(buf)
              HTTPResponse.read_new(@socket).value
            end
            # Server Name Indication (SNI) RFC 3546
            s.hostname = @address if s.respond_to? :hostname=
            if @ssl_session and
                Time.now < @ssl_session.time + @ssl_session.timeout
              s.session = @ssl_session if @ssl_session
            end
            Timeout.timeout(@open_timeout, Net::OpenTimeout) { s.connect }
            if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
              s.post_connection_check(@address)
            end
            @ssl_session = s.session
          rescue => exception
            D "Conn close because of connect error #{exception}"
            @socket.close if @socket and not @socket.closed?
            raise exception
          end
        end
        on_connect
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
