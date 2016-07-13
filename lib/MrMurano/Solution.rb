require 'uri'
require 'net/http'
require 'net/http/post/multipart'
require 'json'
require 'date'
require 'digest/sha1'
require 'pp'

module MrMurano
  class SolutionBase
    def initialize
      @token = Account.new.token
      @sid = $cfg['solution.id']
      raise "No solution!" if @sid.nil?
      @uriparts = [:solution, @sid]
    end

    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
    def http
      uri = URI('https://' + $cfg['net.host'])
      if @http.nil? then
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = true
        @http.start
      end
      @http
    end

    def set_req_defaults(request)
      request.content_type = 'application/json'
      request['authorization'] = 'token ' + @token
      request
    end

    def workit(request, &block)
      set_req_defaults(request)
      if block_given? then
        yield request, http()
      else
        response = http().request(request)
        case response
        when Net::HTTPSuccess
          return JSON.parse(response.body)
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          raise response
        end
      end
    end

    def get(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Get.new(uri), &block) 
    end

    def post(path='', body={}, &block)
      uri = endPoint(path)
      req = Net::HTTP::Post.new(uri)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def put(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Put.new(uri))
    end

    def delete(path='', &block)
      uri = endPoint(path)
      workit(Net::HTTP::Delete.new(uri))
    end

    # …

  end
  class Solution < SolutionBase
    def version
      get('/version')
    end

    def info
      get()
    end

    # …/serviceconfig
    def sc # TODO understand this. (i think it has to do with getting data to flow)
      get('/serviceconfig/')
    end
  end

  # …/file 
  class File < SolutionBase
    def initialize
      super
      @uriparts << 'file'
    end

    ##
    # Get a list of all of the static content
    def list
      get()
    end

    ##
    # Get one item of the static content.
    def fetch(path, &block)
      get('/'+path) do |request, http|
        http.request(request) do |resp|
          case resp
          when Net::HTTPSuccess
            if block_given? then
              resp.read_body &block
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            raise resp
          end
        end
        nil
      end
    end

#    def push(local, remote, force=false)
#        sha1 = Digest::SHA1.file(local.to_s).hexdigest
#    end

    ##
    # Delete a file
    def remove(path)
      # TODO test
      delete('/'+path)
    end

    ##
    # Upload a file
    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname

      mime=`file -I -b #{local.to_s}`
      mime='application/octect' if mime.nil?

      uri = endPoint('upload/' + remote)
      upper = UploadIO.new(File.new(localfile), mime, local.basename)
			req = Net::HTTP::Post::Multipart.new(uri, 'file'=> upper )
      workit(req)
    end

    def pull(into, overwrite=false)
      into = Pathname.new(into) unless into.kind_of? Pathname
      into.mkdir unless into.exist?
      raise "Not a directory: #{into.to_s}" unless into.directory?
      key = :path

      there = list()
      there.each do |item|
        name = item[key.to_s]
        raise "Bad key(#{key}) for #{item}" if name.nil?
        name = 'index.html' if name == '/' # FIXME make generic and configable

        if not (into + name).exist? or overwrite then
          (into+name).open('wb') do |outio|
            fetch(item[key.to_s]) do |chunk|
              outio.write chunk
            end
          end
        end
      end

    end

  end

  # …/role
  class Role < SolutionBase
    def initialize
      super
      @uriparts << 'role'
    end

    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    # delete
    # create
    # update?
  end

  # …/user
  class User < SolutionBase
    def initialize
      super
      @uriparts << 'user'
    end

    def list()
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    # delete
    # create
    # update?
  end

  # …/endpoint
  class Endpoint < SolutionBase
    def initialize
      super
      @uriparts << 'endpoint'
    end

    ##
    # This gets all data about all endpoints
    def list
      get()
    end

    def fetch(id)
      get('/' + id.to_s)
    end

    ##
    # Create endpoint
    # This also acts as update.
    def create(method, path, script)
      post('', {:method=>method, :path=>path, :script=>script})
    end

    ##
    # Delete an endpoint
    def remove(id)
      delete('/' + id.to_s)
    end
  end

  # …/library
  class Library < SolutionBase
    def initialize
      super
      @uriparts << 'library'
    end

    def mkalias(name)
      "/#{$cfg['solution.id']}_#{name}"
    end

    def list
      get()
    end

    def fetch(name)
      get(mkalias(name))
    end

    # ??? remove
    def remove(name)
      # TODO Test this, I'm guesing.
      delete(mkalias(name))
    end

    def create(name, script)
      pst = {
        :name => name,
        :solution_id => $cfg['solution.id'],
        :script => script
      }
      post(mkalias(name), pst)
    end
    # XXX Or should create & update be merged into a single action?
    # Will think more on it when the sync methods get written.
    def update(name, script)
      pst = {
        :name => name,
        :solution_id => $cfg['solution.id'],
        :script => script
      }
      put(mkalias(name), pst)
    end
  end

  # …/eventhandler

  # How do we enable product.id to flow into the eventhandler?
end

#
# I think what I want for top level commands is a 
# - sync --up   : Make servers like my working dir
# - sync --down : Make working dir like servers
#   --no-delete : Don't delete things at destination
#   --no-create : Don't create things at destination
#   --no-update : Don't update things at destination
# 
# And then various specific commands.
# fe: mr file here there to upload a single file
#     mr file --pull there here
#
# or
#   mr pull --file here there
#   mr push --file here there
#   mr pull --[file,user,role,endpoint,…]
command :solution do |c|
  c.syntax = %{mr solution ...}

  c.action do |args, options|

    sol = MrMurano::File.new
    say sol.list
    #say sol.fetch('1')

  end
end

command :pull do |c|
  c.syntax = %{mr pull}
  c.description = %{For a project, pull a copy of everything down.}
  c.option '--overwrite', 'Replace local files.'

  c.option '--files', 'Pull static files down'

  c.action do |args, options|


    if options.files then
      sol = MrMurano::File.new
      sol.pull( $cfg['location.base'] + $cfg['location.files'] )

    end

  end
end

#  vim: set ai et sw=2 ts=2 :
