require 'MrMurano/SubCmdGroupContext'

command :solution do |c|
  c.syntax = %{murano solution}
  c.summary = %{About Solution}
  c.description = %{Sub-commands for working with solutions}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

#  vim: set ai et sw=2 ts=2 :
