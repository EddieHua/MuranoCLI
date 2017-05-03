require 'MrMurano/Account'
require 'terminal-table'

command 'solution list' do |c|
  c.syntax = %{murano solution list [options]}
  c.description = %{List solutions}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    acc = MrMurano::Account.new
    data = acc.solutions

    io=nil
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

#  vim: set ai et sw=2 ts=2 :
