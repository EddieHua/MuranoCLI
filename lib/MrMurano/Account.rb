require 'uri'
require 'net/http'
require 'json'
require 'date'
require 'pathname'
require 'yaml'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'

module MrMurano
  class Passwords
    def initialize(path)
      path = Pathname.new(path) unless path.kind_of? Pathname
      @path = path
      @data = nil
    end
    def load()
      if @path.exist? then
        @path.chmod(0600)
        @path.open('rb') do |io|
          @data = YAML.load(io)
        end
      end
    end
    def save()
      @path.dirname.mkpath unless @path.dirname.exist?
      @path.open('wb') do |io|
        io << @data.to_yaml
      end
      @path.chmod(0600)
    end
    def set(host, user, pass)
      unless @data.kind_of? Hash then
        @data = {host=>{user=>pass}}
        return
      end
      hd = @data[host]
      if hd.nil? or not hd.kind_of?(Hash) then
        @data[host] = {user=>pass}
        return
      end
      @data[host][user] = pass
      return
    end
    def get(host, user)
      return ENV['MR_PASSWORD'] unless ENV['MR_PASSWORD'].nil?
      return nil unless @data.kind_of? Hash
      return nil unless @data.has_key? host
      return nil unless @data[host].kind_of? Hash
      return nil unless @data[host].has_key? user
      return @data[host][user]
    end
  end

  class Account
    include Http
    include Verbose

    def endPoint(path)
      URI('https://' + $cfg['net.host'] + '/api:1/' + path.to_s)
    end

    def _loginInfo
      host = $cfg['net.host']
      user = $cfg['user.name']
      if user.nil? or user.empty? then
        error("No Murano user account found; please login")
        user = ask("User name: ")
        $cfg.set('user.name', user, :user)
      end
      pff = $cfg.file_at('passwords', :user)
      pf = Passwords.new(pff)
      pf.load
      pws = pf.get(host, user)
      if pws.nil? then
        error("Couldn't find password for #{user}")
        pws = ask("Password:  ") { |q| q.echo = "*" }
        pf.set(host, user, pws)
        pf.save
      end
      {
        :email => $cfg['user.name'],
        :password => pws
      }
    end

    # Store the token in a class variable so that we only fetch it once per run
    # session of this tool
    @@token = nil
    def token
      if @@token.nil? then
        # Cannot have token call token, so cannot use workit.
        uri = endPoint('token/')
        request = Net::HTTP::Post.new(uri)
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request.content_type = 'application/json'
        curldebug(request)
        #request.basic_auth(username(), password())
        request.body = JSON.generate(_loginInfo)

        response = http.request(request)
        case response
        when Net::HTTPSuccess
          token = JSON.parse(response.body, json_opts)
          @@token = token[:token]
        else
          showHttpError(request, response)
          error "Check to see if username and password are correct."
          @@token = nil
        end
      end
      @@token
    end

    def token_reset(value=nil)
      @@token = value
    end

    def businesses
      _loginInfo if $cfg['user.name'].nil?
      get('user/' + $cfg['user.name'] + '/membership/')
    end

    #------------------------------------------------------------------------
    def products
      raise "Missing Business ID" if $cfg['business.id'].nil?
      get('business/' + $cfg['business.id'] + '/product/')
    end

    ## Create a new product in the current business
    def new_product(name, type='onepModel')
      raise "Missing Business ID" if $cfg['business.id'].nil?
      post('business/' + $cfg['business.id'] + '/product/', {:label=>name, :type=>type})
    end

    def delete_product(modelId)
      raise "Missing Business ID" if $cfg['business.id'].nil?
      delete('business/' + $cfg['business.id'] + '/product/' + modelId)
    end

    #------------------------------------------------------------------------
    def solutions
      raise "Missing Business ID" if $cfg['business.id'].nil?
      get('business/' + $cfg['business.id'] + '/solution/')
    end

    ## Create a new solution in the current business
    def new_solution(name, type='dataApi')
      raise "Missing Business ID" if $cfg['business.id'].nil?
      raise "Solution name must be lowercase" if name.match(/[A-Z]/)
      post('business/' + $cfg['business.id'] + '/solution/', {:label=>name, :type=>type})
    end

    def delete_solution(apiId)
      raise "Missing Business ID" if $cfg['business.id'].nil?
      delete('business/' + $cfg['business.id'] + '/solution/' + apiId)
    end

    #------------------------------------------------------------------------
    def projects
      raise "Missing Business ID" if $cfg['business.id'].nil?
      get('business/' + $cfg['business.id'] + '/project/')
    end

    ## Create a new solution in the current business
    def new_project(name)
      raise "Missing Business ID" if $cfg['business.id'].nil?
      # TODO name must be valid for domain names.
      #raise "Solution name must be lowercase" if name.match(/[A-Z]/)

      post('business/' + $cfg['business.id'] + '/project/', {:label=>name})
    end

    def delete_project(apiId)
      raise "Missing Business ID" if $cfg['business.id'].nil?
      delete('business/' + $cfg['business.id'] + '/project/' + apiId)
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
