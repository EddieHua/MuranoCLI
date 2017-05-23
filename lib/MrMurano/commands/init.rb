require 'MrMurano/Account'
require 'MrMurano/Config-Migrate'
require 'erb'


command :init do |c|
  c.syntax = %{murano init}
  c.summary = %{The easy way to start a project}
  c.description = %{}

  c.option '--force', %{Override existing business, solution, or product ids}
  c.option '--[no-]mkdirs', %{Create default directories}

  c.action do |args, options|
    options.default :force=>false, :mkdirs=>true
    acc = MrMurano::Account.new
    puts ''

    if Pathname.new(Dir.pwd).realpath == Pathname.new(Dir.home).realpath then
      acc.error "Cannot init a project in your HOME directory."
      exit 2
    end

    say "Found project base directory at #{$cfg['location.base'].to_s}"
    puts ''

    # Try to import a .Solutionfile.secret
    MrMurano::ConfigMigrate.new.import_secret

    # If they have never logged in, then asking for the business.id will also ask
    # for their username and password.
    say "Using account #{$cfg['user.name']}"
    say ''

    # 1. Get business id
    if not options.force and not $cfg['business.id'].nil? then
      say "Using Business ID already set to #{$cfg['business.id']}"
    else
      bizz = acc.businesses
      if bizz.count == 1 then
        bizid = bizz.first
        say "You are only part of one business; using #{bizid[:name]}"
        $cfg.set('businesses.id', bizid[:bizid], :project)

      elsif bizz.count == 0 then
        acc.warning "You don't have any businesses; Log into the webUI and create one."
        exit 3
      else
        choose do |menu|
          menu.prompt = "Select which Business to use:"
          menu.flow = :columns_across
          bizz.sort{|a,b| a[:name]<=>b[:name]}.each do |b|
            menu.choice(b[:name]) do
              $cfg.set('business.id', b[:bizid], :project)
            end
          end
        end
      end
    end
    puts '' # blank line

    # 2. Get Solution id
    if not options.force and not $cfg['solution.id'].nil? then
      say "Using Solution ID already set to #{$cfg['solution.id']}"
    else
      solz = acc.solutions.select{|s| s[:type] == 'dataApi'}
      if solz.count == 1 then
        sol = solz.first
        say "You only have one solution; using #{sol[:domain]}"
        $cfg.set('solution.id', sol[:apiId], :project)

      elsif solz.count == 0 then
        say "You don't have any solutions; lets create one"
        solname = ask("Solution Name? ")
        ret = acc.new_solution(solname)
        if ret.nil? then
          acc.error "Create Solution failed"
          exit 5
        end
        if not ret.kind_of?(Hash) and not ret.empty? then
          acc.error "Create Solution failed: #{ret.to_s}"
          exit 2
        end

        # create doesn't return anything, so we need to go look for it.
        ret = acc.solutions.select{|i| i[:domain] =~ /#{solname}\./}
        sid = ret.first[:apiId]
        if sid.nil? or sid.empty? then
          acc.error "Solution didn't find an apiId!!!!  #{ret}"
          exit 3
        end
        $cfg.set('solution.id', sid, :project)

      else
        choose do |menu|
          menu.prompt = "Select which Solution to use:"
          menu.flow = :columns_across
          solz.sort{|a,b| a[:domain]<=>b[:domain]}.each do |s|
            menu.choice(s[:domain].sub(/\..*$/,'')) do
              $cfg.set('solution.id', s[:apiId], :project)
            end
          end
        end
      end
    end
    puts '' # blank line

    # 3. Get Product id
    if not options.force and not $cfg['product.id'].nil? then
      say "Using Product ID already set to #{$cfg['product.id']}"
    else
      podz = acc.products
      if podz.count == 1 then
        prd = podz.first
        say "You only have one product; using #{prd[:label]}"
        $cfg.set('product.id', prd[:modelId], :project)

      elsif podz.count == 0 then
        say "You don't have any products; lets create one"
        podname = ask("Product Name? ")
        ret = acc.new_product(podname)
        if ret.nil? then
          acc.error "Create Product failed"
          exit 5
        end
        if not ret.kind_of?(Hash) and not ret.empty? then
          acc.error "Create Product failed: #{ret.to_s}"
          exit 2
        end

        # create doesn't return anything, so we need to go look for it.
        ret = acc.products.select{|i| i[:label] == podname}
        pid = ret.first[:modelId]
        if pid.nil? or pid.empty? then
          acc.error "Product didn't find an apiId!!!!  #{ret}"
          exit 3
        end
        $cfg.set('product.id', pid, :project)

      else
        choose do |menu|
          menu.prompt = "Select which Product to use:"
          menu.flow = :columns_across
          podz.sort{|a,b| a[:label]<=>b[:label]}.each do |p|
            menu.choice(p[:label]) do
              $cfg.set('product.id', p[:modelId], :project)
            end
          end
        end
      end
    end

    puts ''
    say "Ok, In business ID: #{$cfg['business.id']} using Solution ID: #{$cfg['solution.id']} with Product ID: #{$cfg['product.id']}"

    # If no ProjectFile, then write a ProjectFile
    if not $project.usingProjectfile then
      tmpl = File.read(File.join(File.dirname(__FILE__),'..','template','projectFile.murano.erb'))
      tmpl = ERB.new(tmpl)
      res = tmpl.result($project.data_binding)
      prFile = $project['info.name'] + '.murano'
      say "Writing an initial Project file: #{prFile}"
      File.open(prFile, 'w') {|io| io << res}
    end

    if options.mkdirs then
      base = $cfg['location.base']
      base = Pathname.new(base) unless base.kind_of? Pathname
      %w{
        location.files
        location.endpoints
        location.modules
        location.eventhandlers
        location.specs
      }.each do |cfgi|
        path = $cfg[cfgi]
        path = Pathname.new(path) unless path.kind_of? Pathname
        path = base + path
        unless path.exist? then
          path = path.dirname unless path.extname.empty?
          path.mkpath
        end
      end
      say "Default directories created"
    end

  end
end

#  vim: set ai et sw=2 ts=2 :
