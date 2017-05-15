require 'date'
require 'MrMurano/Solution-ServiceConfig'
require 'MrMurano/SubCmdGroupContext'

module MrMurano
  module ServiceConfigs
    class Tsdb < ServiceConfig
      def initialize
        super
        @serviceName = 'tsdb'
      end

      def write(data)
        call(:write, :post, data)
      end

      def query(query)
        call(:query, :post, query)
      end

      def listTags
        call(:listTags)
      end

      def listMetrics
        call(:listMetrics)
      end


      def str_to_timestamp(str)
        if str =~ /^\d+(u|ms|s)?$/ then
          str
        else
          dt = DateTime.parse(str)
          (dt.to_time.to_f * 1000000).to_i
        end
      end
    end
  end
end

command 'tsdb write' do |c|
  c.syntax = %{murano tsdb write [options] <metric=value>|@<tag=value> … }
  c.summary = %{write data}
  c.description = %{Write data

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  }
  c.option '--when TIMESTAMP', %{When this data happened. (defaults to now)}
  # TODO: add option to take data from STDIN.
  c.example 'murano tsdb write hum=45 lux=12765 @sn=44', %{Write two metrics (hum and lux) with a tag (sn)}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new

    # we have hash of tags, hash of metrics, optional timestamp.
    metrics = {}
    tags = {}
    args.each do |item|
      key, value = item.split('=', 2)
      if key[0] == '@' then
        tags[key[1..-1]] = value.to_s  #tags are always strings.
      else
        value = value.to_i if value == value.to_i.to_s
        metrics[key] = value
      end
    end

    data = {:tags=>tags, :metrics=>metrics}
    if not options.when.nil? and options.when != 'now' then
      data[:ts] = sol.str_to_timestamp(options.when)
    end

    ret = sol.write(data)
    if ret != {} then
      sol.error ret
    end
  end
end

command 'tsdb query' do |c|
  c.syntax = %{murano tsdb query [options] <metric>|@<tag=value> …}
  c.summary = %{query data}
  c.description =%{Query data from the TSDB.

FUNCS is a comma separated list of the aggregate functions.
Currently: avg, min, max, count, sum.  For string metrics, only count.

FILL is null, none, any integer, previous

DURATION is an integer with time unit to indicate relative time before now.
Units are u (microseconds), ms (milliseconds), s (seconds), m (minutes),
h (hours), d (days), w (weeks)

TIMESTAMP is microseconds since unix epoch, or can be suffixed with units.
Units are u (microseconds), ms (milliseconds), s (seconds)

Also, many date-time formats can be parsed and will be converted to microseconds
  }
  c.option '--start_time TIMESTAMP', %{Start time range}
  c.option '--end_time TIMESTAMP', %{End time range; defaults to now}
  c.option '--relative_start DURATION', %{Start time relative from now}
  c.option '--relative_end DURATION', %{End time relative from now}
  c.option '--sampling_size DURATION', %{The size of time slots used for downsampling}
  c.option '--limit NUM', Integer, %{Limit number of data points returned}
  c.option '--epoch UNIT', ['u','ms','s'], %{Set size of returned timestamps}
  c.option '--mode MODE', ['merge','split'], %{Merge or split each returned metric}
  c.option '--fill FILL', %{Value to fill for time slots with no data points exist in merge mode}
  c.option '--order_by ORDER', ['desc','asc'], %{Return results in ascending or descending time order}
  c.option '--aggregate FUNCS', %{Aggregation functions to apply}

  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.example 'murano tsdb query hum', 'Get all hum metric entries'
  c.example 'murano tsdb query hum @sn=45', 'Get all hum metric entries for tag sn=45'
  c.example 'murano tsdb query hum --limit 1', 'Get just the most recent entry'
  c.example 'murano tsdb query hum --relative_start 1h', 'Get last hour of hum entries'
  c.example 'murano tsdb query hum --relative_start -1h', 'Get last hour of hum entries'
  c.example 'murano tsdb query hum --relative_start 2h --relative_end 1h', 'Get hum entries of two hours ago, but not the last hours'
  c.example 'murano tsdb query hum --sampling_size 30m', 'Get one hum entry from each 30 minute chunk of time'
  c.example 'murano tsdb query hum --sampling_size 30m --aggregate avg', 'Get average hum entry from each 30 minute chunk of time'


  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new

    query = {}
    tags = {}
    metrics = []
    args.each do |arg|
      if arg =~ /=/ then
        # a tag.
        k,v = arg.split('=', 2)
        k = k[1..-1] if k[0] == '@'
        tags[k] = v
      else
        metrics << arg
      end
    end
    query[:tags] = tags unless tags.empty?
    query[:metrics] = metrics unless metrics.empty?

    # A query without any metrics is invalid.  So if the user didn't provide any,
    # look up all of them (well, frist however many) and use that list.
    if query[:metrics].nil? or query[:metrics].empty? then
      ret = sol.listMetrics
      query[:metrics] = ret[:metrics]
    end

    unless options.start_time.nil? then
      query[:start_time] = sol.str_to_timestamp(options.start_time)
    end
    unless options.end_time.nil? then
      query[:end_time] = sol.str_to_timestamp(options.end_time)
    end

    unless options.relative_start.nil? then
      o = options.relative_start
      o = "-#{o}" unless o[0] == '-'
      query[:relative_start] = o
    end
    unless options.relative_end.nil? then
      o = options.relative_end
      o = "-#{o}" unless o[0] == '-'
      query[:relative_end] = o
    end
    query[:sampling_size] = options.sampling_size unless options.sampling_size.nil?

    query[:limit] = options.limit unless options.limit.nil?
    query[:epoch] = options.epoch unless options.epoch.nil?
    query[:mode] = options.mode unless options.mode.nil?
    query[:order_by] = options.order_by unless options.order_by.nil?

    query[:fill] = options.fill unless options.fill.nil?
    unless options.aggregate.nil? then
      query[:aggregate] = options.aggregate.split(',')
    end

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end
    sol.outf sol.query(query) do |dd, ios|
      # If aggregated, then we need to break up the columns. since each is now a
      # hash of the aggregated functions
      unless options.aggregate.nil? then
        dd[:values].map! do |row|
          row.map do |value|
            if value.kind_of? Hash then
              query[:aggregate].map{|qa| value[qa.to_sym]}
            else
              value
            end
          end.flatten
        end
        dd[:columns].map! do |col|
          if col == 'time' then
            col
          else
            query[:aggregate].map{|qa| "#{col}.#{qa.to_s}"}
          end
        end.flatten!
      end
      sol.tabularize({
        :headers=>dd[:columns],
        :rows=>dd[:values]
      }, ios)
    end
    io.close unless io.nil?
  end
end

command 'tsdb list tags' do |c|
  c.syntax = %{murano tsdb list tags [options]}
  c.summary = %{List tags}
  c.option '--values', %{Also return the known tag values}

  c.action do |args, options|
    options.default :values=>false

    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listTags
    # TODO: handle looping if :next != nil

    if options.values then
      sol.outf(ret[:tags]) do |dd, ios|
        data={}
        data[:headers] = dd.keys
        data[:rows] = dd.keys.map{|k| dd[k]}
        len = data[:rows].map{|i| i.length}.max
        data[:rows].each{|r| r.fill(nil, r.length, len - r.length)}
        data[:rows] = data[:rows].transpose
        sol.tabularize(data, ios)
      end
    else
      sol.outf ret[:tags].keys
    end


  end
end

command 'tsdb list metrics' do |c|
  c.syntax = %{murano tsdb list metrics}
  c.summary = %{List metrics}

  c.action do |args, options|
    sol = MrMurano::ServiceConfigs::Tsdb.new
    ret = sol.listMetrics
    # TODO: handle looping if :next != nil
    sol.outf ret[:metrics]
  end
end

command :tsdb do |c|
  c.syntax = %{murano tsdb}
  c.summary = %{About TSDB}
  c.description = %{The tsdb sub-commands let you interact directly with the TSDB instance in a
solution.  This allows for easier debugging, being able to quickly try out
different queries or write test data.}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

#  vim: set ai et sw=2 ts=2 :
