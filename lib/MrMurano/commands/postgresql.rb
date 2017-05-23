require 'MrMurano/Solution-ServiceConfig'

module MrMurano
  class Postgresql < ServiceConfig
    def initialize
      super
      @serviceName = 'postgresql'
    end

    def query(query, params=nil)
      aqr = {:sql=>query}
      aqr[:parameters] = params unless params.nil?
      call(:query, :post, aqr)
    end

    def queries(query, params=nil)
      aqr = {:sql=>query}
      aqr[:parameters] = params unless params.nil?
      call(:queries, :post, aqr)
    end
  end
end

command :postgresql do |c|
  c.syntax = %{murano postgresql <SQL Commands>}
  c.summary = %{Query the relational database}
  c.description = %{Query the relational database

  Queries can include $# escapes that are filled from the --param option.
  }

  c.option '--param LIST',Array,  %{Values to fill $# with}
  c.option '-f', '--file FILE', %{File of SQL commands}
  c.option '-o', '--output FILE', %{Download to file instead of STDOUT}

  c.example %{murano postgresql 'select * from bob'}, %{Run a SQL command}
  c.example %{murano postgresql 'select * from prices' -c outformat=csv -o prices.csv}, %{Download all values in prices to a CSV file.}
  c.example %{murano postgresql 'INSERT INTO prices (price, item) VALUES ($1,$2)' --param 1.24,Food}, %{Insert using parameters.}
  c.example %{murano postgresql -f cmds.sql}, %{Run multiple commands from a file}

  c.action do |args,options|
    pg = MrMurano::Postgresql.new
    if options.file then
      sqls = File.read(options.file)

      ret = pg.queries(sqls, options.param)
    else
      ret = pg.query(args.join(' '), options.param)
    end

    unless ret[:error].nil? then
      pg.error "Returned error: #{ret[:error]}"
      exit 1
    end

    io=nil
    if options.output then
      io = File.open(options.output, 'w')
    end

    pg.outf(ret, io) do |dd, ios|
      dd = dd[:result]
      pg.tabularize({
        :headers=>dd[:columns],
        :rows=>dd[:rows]
      }, ios)
    end
    io.close unless io.nil?

  end
end

command 'postgresql migrate' do |c|
  c.syntax = %{murano postgresql migrate (up|down) <level>}
  c.summary = %{Run database migration scripts.}
  c.description = %{Run database migration scripts.

  The names of the script files must be in the "<level>-<name>-<up|down>.sql"
  format.  Each file is a series of Postgres SQL commands.

  The current version of the migrations (last <level> ran) will be stored in an
  extra table in your database.  (__murano_cli__.migrate_version)

  }

  c.option '--dir DIR', %{Directory where migrations live}

  c.example %{murano postgresql migrate up}, %{Run migrations up to largest version.}
  c.example %{murano postgresql migrate up 2}, %{Run migrations up to version 2.}
  c.example %{murano postgresql migrate down 1}, %{Run migrations down to version 1.}
  c.example %{murano postgresql migrate down 0}, %{Run migrations down to version 0.}

  c.action do |args,options|
    options.default :dir => File.join($cfg['location.base'], $cfg['postgresql.migrations_dir'])

    direction = args.shift
    if direction =~ /down/i then
      direction = 'down'
    else
      direction = 'up'
    end

    want_version = args.first

    pg = MrMurano::Postgresql.new

    # get current version of DB.
    ret = pg.queries %{
    CREATE SCHEMA IF NOT EXISTS __murano_cli__;
    CREATE TABLE IF NOT EXISTS __murano_cli__.migrate_version (version integer);
    SELECT version FROM __murano_cli__.migrate_version ORDER BY version DESC;
    }.gsub(/^\s+/,'')
    unless ret[:error].nil? then
      pp ret
      exit 1
    end
    pg.debug "create/select: #{ret}"
    current_version = (((((ret[:result] or []).last or {})[:rows] or []).first or []).first or 0).to_i

    # Get migrations
    migrations = Dir[File.join(options.dir, "*-#{direction}.sql")].sort
    if migrations.empty? then
      pg.error "No migrations to run."
      exit 1
    end
    migrations.reverse! if direction == 'down'

    if want_version.nil? then
      want_version, _ = File.basename(migrations.last).split('-')
    end
    want_version = want_version.to_i
    pg.verbose "Will migrate from version #{current_version} to #{want_version}"
    if direction == 'down' then
      if want_version >= current_version then
        say "Nothing to do."
        exit 0
      end
    else
      if want_version <= current_version then
        say "Nothing to do."
        exit 0
      end
    end

    pg.debug "Migrations before: #{migrations}"
    # Select migrations between current and desired
    migrations.select! do |m|
      mvrs, _ = File.basename(m).split('-')
      mvrs = mvrs.to_i
      if direction == 'down' then
        mvrs <= current_version and mvrs > want_version
      else
        mvrs > current_version and mvrs <= want_version
      end
    end
    pg.debug "Migrations after: #{migrations}"

    # Run migrations.
    migrations.each do |m|
      mvrs, _ = File.basename(m).split('-')
      pg.verbose "Running migration: #{File.basename(m)}"
      unless $cfg['tool.dry'] then
        pg.query 'BEGIN;'
        ret = pg.queries File.read(m)
        unless ret[:error].nil? then
          pg.query 'ROLLBACK;'
          pg.error "Migrations failed at level #{mvrs}"
          pg.error "Because: #{ret[:error]}"
          exit 5
        else
          if direction == 'down' then
            pg.queries %{DELETE FROM __murano_cli__.migrate_version WHERE version = #{mvrs};
              COMMIT;}.gsub(/^\s+/,'')
          else
            pg.queries %{INSERT INTO __murano_cli__.migrate_version values (#{mvrs});
              COMMIT;}.gsub(/^\s+/,'')
          end
        end
      end
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
