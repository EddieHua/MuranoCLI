require 'MrMurano/OnePlatform'

command :content do |c|
  c.syntax = %{murano content}
  c.summary = %{About Content Area}
  c.description = %{This set of commands let you interact with the content area for a product.

This is where OTA data can be stored so that devices can easily download it.
}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'content list' do |c|
  c.syntax = %{murano content list}
  c.summary = %{List downloadable content for a product}
  c.description = %{List downloadable content for a product

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  }
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    prd.outf prd.list
  end
end

command 'content info' do |c|
  c.syntax = %{murano content info <content id>}
  c.summary = %{Show more info for a content item}
  c.description = %{Show more info for a content item

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  }
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    if args[0].nil? then
      prd.error "Missing <content id>"
    else
      prd.tabularize prd.info(args[0])
    end
  end
end

command 'content delete' do |c|
  c.syntax = %{murano content delete <content id>}
  c.summary = %{Delete a content item}
  c.description = %{Delete a content item

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  }
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    if args[0].nil? then
      prd.error "Missing <content id>"
    else
      ret = prd.remove(args[0])
      prd.outf(ret) unless ret.nil? or ret.empty?
    end
  end
end

command 'content upload' do |c|
  c.syntax = %{murano content upload <content id> <file>}
  c.summary = %{Upload content}
  c.description = %{Upload a content item

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  }
  c.option '--meta STRING', %{Add extra meta info to the content item}

  c.action do |args, options|
    options.default :meta=>' '
    prd = MrMurano::ProductContent.new

    if args[0].nil? then
      prd.error "Missing <content id>"
    elsif args[1].nil? then
      prd.error "Missing <file>"
    else

      ret = prd.info(args[0])
      if ret.nil? then
        ret = prd.create(args[0], options.meta)
        prd.outf(ret) unless ret.nil? or ret.empty?
      end

      ret = prd.upload(args[0], args[1])
      prd.outf(ret) unless ret.nil? or ret.empty?
    end
  end
end

command 'content download' do |c|
  c.syntax = %{murano content download <content id>}
  c.summary = %{Download a content item}
  c.description = %{Download a content item

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  }
  c.option '-o','--output FILE',%{save to this file}
  c.action do |args, options|
    prd = MrMurano::ProductContent.new
    if args[0].nil? then
      prd.error "Missing <content id>"
    else

      if options.output.nil? then
        prd.download(args[0]) # to stdout
      else
        outFile = Pathname.new(options.output)
        outFile.open('w') do |io|
          prd.download(args[0]) do |chunk|
            io << chunk
          end
        end
      end
    end
  end
end


#  vim: set ai et sw=2 ts=2 :
