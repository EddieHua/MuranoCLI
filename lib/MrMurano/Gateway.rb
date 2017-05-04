require 'uri'
require 'net/http'
require 'http/form_data'
require 'json-schema'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Gateway service.
  # This where interfacing to real hardware happens.
  module Gateway
    class Base
      def initialize
        # XXX: MRMUR-94
        @pid = $cfg['project.id']
        raise "No project id!" if @pid.nil?
        @uriparts = [:service, @pid, :device2]
        @itemkey = :id
      end

      include Http
      include Verbose

      ## Generate an endpoint in Murano
      # Uses the uriparts and path
      # @param path String: any additional parts for the URI
      # @return URI: The full URI for this enpoint.
      def endPoint(path='')
        parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
        s = parts.map{|v| v.to_s}.join('/')
        URI(s + path.to_s)
      end
      # …
      #include SyncUpDown

      # Get info for this gateway interface.
      def info
        get()
      end
    end

    class Settings < Base
      # Get the protocol settings
      def protocol
        ret = get()
        return {} if ret.nil?
        return {} unless ret.kind_of? Hash
        return {} unless ret.has_key? :protocol
        return {} unless ret[:protocol].kind_of? Hash
        return ret[:protocol]
      end

      # Set the protocol settings
      def protocol=(x)
        raise "Not Hash" unless x.kind_of? Hash
        x.delete_if {|k,v| not [:name, :devmode].include? k}
        patch('', {:protocol => x})
      end

      def identity_format
        ret = get()
        return {} if ret.nil?
        return {} unless ret.kind_of? Hash
        return {} unless ret.has_key? :identity_format
        return {} unless ret[:identity_format].kind_of? Hash
        return ret[:identity_format]
      end

      def identity_format=(x)
        raise "Not Hash" unless x.kind_of? Hash
        raise "Not Hash" if x.has_key? :options and not x[:options].kind_of? Hash
        x.delete_if {|k,v| not [:type, :prefix, :options].include? k}
        x[:options].delete_if {|k,v| not [:casing, :length].include? k}
        patch('', {:identity_format=>x})
      end

      def provisioning
        ret = get()
        return {} if ret.nil?
        return {} unless ret.kind_of? Hash
        return {} unless ret.has_key? :provisioning
        return {} unless ret[:provisioning].kind_of? Hash
        return ret[:provisioning]
      end
      def provisioning=(x)
        raise "Not Hash" unless x.kind_of? Hash
        raise "Not Hash" if x.has_key? :ip_whitelisting and not x[:ip_whitelisting].kind_of? Hash
        x.delete_if {|k,v| not [:enabled, :auth_type, :generate_identity, :presenter_identity, :ip_whitelisting].include? k}
        x[:ip_whitelisting].delete_if {|k,v| not [:enabled, :allowed].include? k}
        patch('', {:provisioning=>x})
      end
    end

    ##############################################################################
    ## Working with the resources on a set of Devices. (Gateway)
    class Resources < Base
      include SyncUpDown
      def initialize
        super
        @itemkey = :alias
        @project_section = :resources
      end

      def list()
        ret = get('')
        return [] unless ret.has_key? :resources

        # convert hash to array.
        res = []
        ret[:resources].each_pair do |key, value|
          res << value.merge({:alias=>key.to_s})
        end
        res
      end

      def upload_all(data)
        # convert array to hash
        res = {}
        data.each do |value|
          key = value[:alias]
          res[key] = value.reject{|k,v| k==:alias}
        end

        patch('', {:resources=>res})
      end

      ###################################################
      def syncup_before()
        @there = list()
      end

      def remove(itemkey)
        @there.delete_if {|item| item[@itemkey] == itemkey}
      end

      def upload(local, remote, modify)
        @there.delete_if {|item| item[@itemkey] == remote[@itemkey]}
        @there << remote.reject{|k,v| k==:synckey}
      end

      def syncup_after()
        upload_all(@there)
        @there = nil
      end

      ###################################################
      def syncdown_before(local)
        @here = locallist()
      end

      def download(local, item)
        # needs to append/merge with file
        @here.delete_if do |i|
          i[@itemkey] == item[@itemkey]
        end
        @here << item.reject{|k,v| k==:synckey}
      end

      def removelocal(local, item)
        # needs to append/merge with file
        key = @itemkey.to_sym
        @here.delete_if do |it|
          it[key] == item[key]
        end
      end

      def syncdown_after(local)
        local.open('wb') do|io|
          # convert array to hash
          res = {}
          @here.each do |value|
            key = value[:alias]
            res[key] = Hash.transform_keys_to_strings(value.reject{|k,v| k==:alias})
          end
          io.write res.to_yaml
        end
        @here = nil
      end

      ###################################################
      def tolocalpath(into, item)
        into
      end

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
        here = {} if here == false

        # Validate file against schema.
        schemaPath = Pathname.new(File.dirname(__FILE__)) + 'schema/resource-v1.0.0.yaml'
        schema = YAML.load_file(schemaPath.to_s)
        JSON::Validator.validate!(schema, here)

        res = []
        here.each_pair do |key, value|
          res << Hash.transform_keys_to_symbols(value).merge({:alias=>key.to_s})
        end
        res
      end

      def docmp(itemA, itemB)
        itemA != itemB
      end
    end
    SyncRoot.add('resources', Resources, 'T', %{Resources.})

    ##############################################################################
    ##
    # Talking to the devices on a Gateway
    class Device < Base
      def initialize
        super
        @uriparts << :identity
      end

      ## All devices (pagination?)
      # @param limit [Number,String] How many devices to return
      # @param before [Number,String] timestamp for something. TODO: want offset.
      def list(limit=nil, before=nil)
        pr = {}
        pr[:limit] = limit unless limit.nil?
        pr[:before] = before unless before.nil?
        pr = nil if pr.empty?
        get('/', pr)
      end

      def query(args)
        # TODO: actually just part of list.
        # ?limit=#
        # ?before=<time stamp in ms>
        # ?status={whitelisted, provisioned, locked, devmode, reprovision}
        # ?identity=<pattern>
        # ?ipaddress=<pattern>
        # ?version=<pattern>
      end

      ## Get one device
      # @param id [String] The identity to fetch
      def fetch(id)
        get("/#{CGI.escape(id.to_s)}")
      end

      ## Create a device with given Identity
      # @param id [String] The new identity
      # @param opts [Hash] Options for the new device
      # @option opts [String] :type One of: certificate, hash, password, signature, token
      # @option opts [String,Pathname,IO] :publickey The certificate, or IO/Pathname to cert file
      # @option opts [String] :privatekey Shared secret for hash, password, token types
      # @option opts [String,Integer] :expire For Cert, when it must be reprovisioned, otherwise when the activation window closes.
      def enable(id, opts=nil)
        unless opts.nil? then
          opts.reject!{|k,v| not [:type, :publickey, :privatekey, :expire].include?(k)}
          if opts.has_key?(:publickey) and not opts[:publickey].kind_of?(String) then
            io = opts[:publickey]
            opts[:publickey] = io.read
          end
        else
          opts={}
        end
        put("/#{CGI.escape(id.to_s)}", opts)
      end
      alias whitelist enable
      alias create enable

      ## Create a bunch of devices at once
      # @param local [String, Pathname] CSV file of identifiers
      # @param expire [Number] Expire time for all identities (ignored)
      # @return [void]
      def enable_batch(local, expire=nil)
        # Need to modify @uriparts for just this endPoint call.
        uriparts = @uriparts
        @uriparts[-1] = :identities
        uri = endPoint()
        @uriparts = uriparts

        file = HTTP::FormData::File.new(local.to_s, {:mime_type=>'text/csv'})
        form = HTTP::FormData.create(:identities=>file)
        req = Net::HTTP::Post.new(uri)
        set_def_headers(req)
        req.content_type = form.content_type
        req.content_length = form.content_length
        req.body = form.to_s
        workit(req)
        nil
      end

      ## Delete a device
      # @param identifier [String] Who to delete.
      def remove(identifier)
        delete("/#{CGI.escape(identifier.to_s)}")
      end

      # Call the device Activation URI.
      #
      # Only useful durring debugging of devices.
      #
      # @param identifier [String] Who to activate.
      def activate(identifier)
        fqdn = Base.new.info()[:fqdn]
        debug "Found FQDN: #{fqdn}"
        fqdn = "#{@pid}.m2.exosite.io" if fqdn.nil?

        uri = URI("https://#{fqdn}/provision/activate")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.start
        request = Net::HTTP::Post.new(uri)
        request.form_data = {
          :vendor => @pid,
          :model => @pid,
          :sn => identifier
        }
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request['Authorization'] = nil
        request.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
        curldebug(request)
        response = http.request(request)
        case response
        when Net::HTTPSuccess
          return response.body
        else
          showHttpError(request, response)
        end
      end

      # Write the set point for aliases on a device
      # @param identifier [String] The identifier for the device to write.
      # @param values [Hash] Aliases and the values to write.
      def write(identifier, values)
        wvalues = Hash[ values.map{|k,v| [k, {:set=>v}]} ]
        debug "Will Write: #{wvalues}"
        put("/#{identifier}/state", wvalues)
      end

      # Read the current state for a device
      # @param identifier [String] The identifier for the device to read.
      def read(identifier)
        get("/#{identifier}/state")
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :


