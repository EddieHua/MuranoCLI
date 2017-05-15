require 'MrMurano/Account'
require 'MrMurano/SubCmdGroupContext'

command :solution do |c|
  c.syntax = %{murano solution}
  c.summary = %{About solution}
  c.description = %{Sub-commands for working with solution}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'solution create' do |c|
  c.syntax = %{murano solution create <name>}
  c.summary = %{Create a new solution}
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES, %{What type of solution to create. (default: product)}
  c.option '--save', %{Save new solution id to config}

  c.action do |args, options|
    options.default :type => :product

    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Name of solution missing"
      return
    end
    name = args[0]

    ret = acc.new_solution(name, options.type)
    if ret.nil? then
      acc.error "Create failed"
      exit 5
    end
    if not ret.kind_of?(Hash) and not ret.empty? then
      acc.error "Create failed: #{ret.to_s}"
      return
    end

    # create doesn't return anything, so we need to go look for it.
    ret = acc.solutions(options.type).select{|i| i[:domain] =~ /#{name}\./}
    pid = ret.first[:apiId]
    if pid.nil? or pid.empty? then
      acc.error "Didn't find an apiId!!!!  #{ret}"
      exit 3
    end
    if options.save then
      $cfg.set('project.id', pid)
    end
    acc.outf pid

  end
end
alias_command 'product create', 'solution create','--type','product'
alias_command 'project create', 'solution create','--type','product'
alias_command 'app create', 'solution create','--type','application'

command 'solution delete' do |c|
  c.syntax = %{murano solution delete <id>}
  c.summary = %{Delete a solution}
  c.description = %{Delete a solution}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "solution id or name missing"
      return
    end
    name = args[0]

    # Need to convert what we got into the internal PID.
    ret = acc.solutions(:all).select{|i| i.has_value?(name) or i[:domain] =~ /#{name}\./ }

    if $cfg['tool.debug'] then
      say "Matches found:"
      acc.outf ret
    end

    if ret.empty? then
      acc.error "No solution matching '#{name}' found. Nothing to delete."
    else
      ret = acc.delete_solution(ret.first[:sid])
      if not ret.kind_of?(Hash) and not ret.empty? then
        acc.error "Delete failed: #{ret.to_s}"
      end
    end
  end
end
alias_command 'product delete', 'solution delete','--type','product'
alias_command 'project delete', 'solution delete','--type','product'
alias_command 'app delete', 'solution delete','--type','application'

command 'solution list' do |c|
  c.syntax = %{murano solution list [options]}
  c.summary = %{List solution}
  c.description = %{List solution in the current business}
  c.option '--type TYPE', MrMurano::Account::ALLOWED_TYPES+[:all], %{What type of solutions to list. (default: all)}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    options.default :type => 'all', :all=>true
    acc = MrMurano::Account.new
    data = acc.solutions(options.type)

    io = nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:apiId]
      data = data.map{|row| [row[:apiId]]}
    elsif not options.all then
      headers = [:apiId, :domain]
      data = data.map{|r| [r[:apiId], r[:domain]]}
    else
      headers = (data.first or {}).keys
      data = data.map{|r| headers.map{|h| r[h]}}
    end

    acc.outf(data, io) do |dd, ios|
      if options.idonly then
        ios.puts dd.join(' ')
      else
        acc.tabularize({
          :headers=>headers.map{|h| h.to_s},
          :rows=>dd
        }, ios)
      end
    end
    io.close unless io.nil?
  end
end
alias_command 'product list', 'solution list', '--type', 'product', '--no-all'
alias_command 'project list', 'solution list', '--type', 'product', '--no-all'
alias_command 'app list', 'solution list', '--type', 'application', '--no-all'

#  vim: set ai et sw=2 ts=2 :
