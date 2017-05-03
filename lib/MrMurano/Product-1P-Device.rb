require 'MrMurano/Product'

module MrMurano
  class Product1PDevice < ProductBase
    include ProductOnePlatformRpcShim

    def initialize
      super
      @uriparts << :proxy
      @uriparts << 'onep:v1'
      @uriparts << :rpc
      @uriparts << :process
      @model_rid = nil
      @sn_rid = nil
    end

    ## Get the internal protocol identifier for a device
    # +sn+:: Identifier for a device
    def sn_rid(sn)
      return @sn_rid unless @sn_rid.nil?
      prd = Product.new()
      found = []

      offset = 0
      loop do
        listing = prd.list(offset)
        break if listing.empty?
        found = listing.select{|item| item[:sn] == sn}
        break unless found.empty?

        offset += 50
      end

      raise "Identifier Not Found: #{sn}" if found.empty?

      @sn_rid = found.first[:rid]
      @sn_rid
    end

    ## Get information about a device
    # +sn+:: Identifier for a device
    def info(sn)
      do_rpc({:id=>1,
              :procedure=>:info,
              :arguments=>[sn_rid(sn), {}]
      }, sn_rid(sn))
    end

    ## List resources on a device
    # +sn+:: Identifier for a device
    def list(sn)
      data = info(sn)
      dt = {}
      data[:aliases].each{|k,v| v.each{|a| dt[a] = k.to_s}}
      dt
    end

    def listing(sn)
      do_rpc({:id=>1,
              :procedure=>:listing,
              :arguments=>[sn_rid(sn), [:dataport], {}]
      }, sn_rid(sn))
    end

    ## Read the last value for resources on a device
    # +sn+:: Identifier for a device
    # +aliases+:: Array of resource names
    def read(sn, aliases)
      aliases = [aliases] unless aliases.kind_of? Array
      calls = aliases.map do |a|
        {
         :procedure=>:read,
         :arguments=>[ {:alias=>a}, {} ]
        }
      end
      do_mrpc(calls, sn_rid(sn)).map do |i|
        if i.has_key?(:result) and i[:result].count > 0 and i[:result][0].count > 1 then
          i[:result][0][1]
        else
          nil
        end
      end
    end

    ## Completely remove an identifier from the product
    # +sn+:: Identifier for a device
    def remove(sn)
      # First drop it from the 1P database
      do_rpc({:id=>1, :procedure=>:drop, :arguments=>[sn_rid(sn)]}, nil)
      # Then remove it from the provisioning databases
      psn = ProductSerialNumber.new
      psn.remove_sn(sn)
    end

    ## Get a tree of info for a device and its resources.
    # @param sn [String] Identifier for a device
    # @return [Hash]
    def twee(sn)
      inf = info(sn)
      return {} if inf.nil?
      return {} unless inf.kind_of? Hash
      return {} unless inf.has_key? :aliases
      return {} unless inf[:aliases].kind_of? Hash
      aliases = inf[:aliases].keys
      # information for all
      info_calls = aliases.map do |rid|
        {:procedure=>:info, :arguments=>[rid, {}]}
      end

      limitkeys = [:basic, :description, :usage, :children, :storage]

      isubs = do_mrpc(info_calls, sn_rid(sn))
      children = isubs.map{|i| i[:result].select{|k,v| limitkeys.include? k} }

      # most current value
      read_calls = aliases.map do |rid|
        {:procedure=>:read, :arguments=>[rid, {}]}
      end
      ivalues = do_mrpc(read_calls, sn_rid(sn))

      rez = aliases.zip(children, ivalues).map do |d|
        dinf = d[1]
        dinf[:rid] = d[0]
        dinf[:alias] = inf[:aliases][d[0]].first

        iv = d[2]
        if iv.has_key?(:result) and iv[:result].count > 0 and iv[:result][0].count > 1 then
          dinf[:value] = iv[:result][0][1]
        else
          dinf[:value] = nil
        end

        dinf
      end

      inf[:children] = rez
      inf.select!{|k,v| limitkeys.include? k }
      inf
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
