require 'MrMurano/Account'

command 'product list' do |c|
  c.syntax = %{murano product list [options]}
  c.description = %{List products}
  c.option '--idonly', 'Only return the ids'
  c.option '--[no-]all', 'Show all fields'
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.action do |args, options|
    acc = MrMurano::Account.new
    data = acc.products

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    if options.idonly then
      headers = [:modelId]
      data = data.map{|row| [row[:modelId]]}
    elsif not options.all then
      headers = [:label, :modelId]
      data = data.map{|r| [r[:label], r[:modelId]]}
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
