
command 'solution create' do |c|
  c.syntax = %{murano solution create <name>}
  c.summary = %{Create a new solution}
  c.option '--save', %{Save new solution id to config}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of solution missing"
      exit 1
    end
    name = args[0]

    ret = acc.new_solution(name)
    if ret.nil? then
      acc.error "Create failed"
      exit 5
    end
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      exit 2
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.solutions.select do |i|
      i[:type] == 'dataApi' and (i[:name] == name or i[:domain] =~ /#{name}\./i)
    end
    sid = (ret.first or {})[:apiId]
    if sid.nil? or sid.empty? then
      acc.error "Didn't find an apiId!!!! #{name} -> #{ret} "
      exit 3
    end
    if options.save then
      $cfg.set('solution.id', sid)
    end
    acc.outf sid

  end
end
#  vim: set ai et sw=2 ts=2 :
