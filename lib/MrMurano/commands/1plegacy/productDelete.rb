require 'MrMurano/Account'

command 'product delete' do |c|
  c.syntax = %{murano product delete <product>}
  c.summary = %{Delete a product}
  c.description = %{Delete a product}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Product id or name missing"
      return
    end
    name = args[0]


    # Need to convert what we got into the internal PID.
    ret = (acc.products or []).select{|i| i.has_value? name }

    acc.debug "Matches found:"
    acc.outf(ret) if $cfg['tool.debug']

    if ret.empty? then
      acc.error "No product matching '#{name}' found. Nothing to delete."
    else
      ret = acc.delete_product(ret.first[:pid])
      if not ret.kind_of?(Hash) and not ret.empty? then
        acc.error "Delete failed: #{ret.to_s}"
      end
    end
  end
end
#  vim: set ai et sw=2 ts=2 :
