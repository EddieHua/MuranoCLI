
command 'product create' do |c|
  c.syntax = %{murano product create <name>}
  c.summary = %{Create a new product}
  c.option '--save', %{Save new product id to config}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of product missing"
      exit 1
    end
    name = args[0]

    ret = acc.new_product(name)
    if ret.nil? then
      acc.error "Create failed"
      exit 5
    end
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      exit 2
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.products.select{|i| i[:label] == name}
    pid = ret.first[:modelId]
    if pid.nil? or pid.empty? then
      acc.error "Didn't find an apiId!!!!  #{ret}"
      exit 3
    end
    if options.save then
      $cfg.set('product.id', pid)
    end
    acc.outf pid

  end
end
#  vim: set ai et sw=2 ts=2 :
