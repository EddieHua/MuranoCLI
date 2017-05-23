require 'MrMurano/SubCmdGroupContext'

command :business do |c|
  c.syntax = %{murano business}
  c.summary = %{About Business}
  c.description = %{Sub-commands for working with Businesses}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

#  vim: set ai et sw=2 ts=2 :

