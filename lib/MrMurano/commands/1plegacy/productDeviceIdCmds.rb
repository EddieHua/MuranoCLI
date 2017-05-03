require 'MrMurano/OnePlatform'
require 'terminal-table'

command 'product device list' do |c|
  c.syntax = %{murano product device list [options]}
  c.summary = %{List serial numbers for a product}

  c.option '--offset NUMBER', Integer, %{Offset to start listing at}
  c.option '--limit NUMBER', Integer, %{How many devices to return}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args,options|
    options.default :offset=>0, :limit=>50

    prd = MrMurano::Product.new
    io=nil
    io = File.open(options.output, 'w') if options.output
    data = prd.list(options.offset, options.limit)
    prd.outf(data, nil) do |dd,ios|
      dt={}
      dt[:headers] = [:SN, :Status, :RID]
      dt[:rows] = data.map{|row| [row[:sn], row[:status], row[:rid]]}
      prd.tabularize(dt, ios)
    end
    io.close unless io.nil?
  end
end
alias_command 'device list', 'product device list'

command 'product device enable' do |c|
  c.syntax = %{murano product device enable [<sn>|--file <sns>]}
  c.summary = %{Enable a serial number; Creates device in Murano}
  c.description = %{Enables serial numbers, creating the digial shadow in Murano.

NOTE: This opens the 24 hour activation window.  If the device does not make
the activation call within this time, it will need to be enabled again.
  }
  c.option '-f', '--file FILE', %{A file of serial numbers, one per line}

  c.action do |args,options|
    prd = MrMurano::Product.new
    if options.file then
      File.open(options.file) do |io|
        io.each_line do |line|
          line.strip!
          prd.enable(line) unless line.empty?
        end
      end
    elsif args.count > 0 then
      prd.enable(args[0])
    else
      prd.error "Missing a serial number to enable"
    end
  end
end
alias_command 'device enable', 'product device enable'

command 'product device activate' do |c|
  c.syntax = %{murano product device activate <sn>}
  c.summary = %{Activate a serial number, retriving its CIK}
  c.description = %{Activates a serial number.

Generally you should not use this.  Instead the device should make the activation
call itself and save the CIK token.  Its just that sometimes when building a
proof-of-concept it is just easier to hardcode the CIK.

Note that you can only activate a device once.  After that you cannot retrive the
CIK again.
}

  c.action do |args,options|
    prd = MrMurano::ProductSerialNumber.new
    if args.count < 1 then
      prd.error "Serial number missing"
      return
    end
    sn = args.first

    prd.outf prd.activate(sn)

  end
end
alias_command 'device activate', 'product device activate'

alias_command 'sn list', 'product device list'
alias_command 'sn enable', 'product device enable'
alias_command 'sn activate', 'product device activate'

#  vim: set ai et sw=2 ts=2 :
