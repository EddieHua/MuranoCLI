require 'MrMurano/Account'

command :business do |c|
  c.syntax = %{murano business}
  c.summary = %{About business}
  c.description = %{
Sub-commands for working with businesses.
  }.strip
  c.project_not_required = true

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'business list' do |c|
  c.syntax = %{murano business list [options]}
  c.summary = %{List businesses}
  c.description = %{
List businesses.
  }.strip
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}
  c.project_not_required = true

  c.action do |args, options|
    acc = MrMurano::Account.new

    MrMurano::Verbose::whirly_start "Looking for businesses..."
    data = acc.businesses
    MrMurano::Verbose::whirly_stop

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:bizid]
      data = data.map{|row| [row[:bizid]]}
    elsif not options.all then
      headers = [:bizid, :role, :name]
      data = data.map{|r| [r[:bizid], r[:role], r[:name]]}
    else
      headers = data[0].keys
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
alias_command 'businesses list', 'business list'

#  vim: set ai et sw=2 ts=2 :

