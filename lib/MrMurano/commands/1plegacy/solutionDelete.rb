require 'MrMurano/Account'

command 'solution delete' do |c|
  c.syntax = %{murano solution delete <solution id>}
  c.description = %{Delete a solution}

  c.action do |args, options|
    acc = MrMurano::Account.new
    if args.count < 1 then
      acc.error "Solution id or name missing"
      return
    end
    name = args[0]


    # Need to convert what we got into the internal PID.
    ret = (acc.solutions or []).select{|i| i.has_value?(name) or i[:domain] =~ /#{name}\./ }

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
#  vim: set ai et sw=2 ts=2 :
