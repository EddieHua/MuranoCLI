require 'MrMurano/Solution'

command :domain do |c|
  c.syntax = %{murano domain}
  c.summary = %{Print the domain for this solution}
  c.option '--[no-]raw', %{Don't add scheme}

  # Add the flags: --types, --ids, --names, --[no]-header.
  command_add_solution_pickers c

  c.action do |args,options|
    options.default :raw=>true

    # FIXME/2017-06-16: [lb] not sure what default should be. All solutions?
    #   Or maybe just Application? If people want to script off the domain, e.g.,
    #     URL=$(murano domain)
    #   maybe default to the Application?
    #   My only reservation is that other commands default to printing all
    #   solutions, e.g., `murano usage`...
    #unless options.type
    #  options.type = :product
    #end
    #options.default :header=>false

    solz = must_fetch_solutions(options)

    domain_s = MrMurano::Verbose::pluralize?("domain", solz.length)
    MrMurano::Verbose::whirly_start "Fetching #{domain_s}..."
    solz.each do |soln|
      # Get the solution info; stores the result in the Solution object.
      desc = soln.info
    end
    MrMurano::Verbose::whirly_stop

    solz.each do |soln|
      if options.header
        #say "#{soln.type}: #{soln.pretty_desc}"
        $stdout.printf "#{soln.type}: "
      end
      if options.raw then
        say soln.desc[:domain]
      else
        say "https://#{soln.desc[:domain]}"
      end
    end

  end
end
alias_command 'domain product', 'domain', '--type', 'product'
alias_command 'domain products', 'domain', '--type', 'product'
alias_command 'domain prod', 'domain', '--type', 'product'
alias_command 'domain prods', 'domain', '--type', 'product'
alias_command 'domain application', 'domain', '--type', 'application'
alias_command 'domain applications', 'domain', '--type', 'application'
alias_command 'domain app', 'domain', '--type', 'application'
alias_command 'domain apps', 'domain', '--type', 'application'

#  vim: set ai et sw=2 ts=2 :

