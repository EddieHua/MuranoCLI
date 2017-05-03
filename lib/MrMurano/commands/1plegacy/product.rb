require 'MrMurano/SubCmdGroupContext'

command :product do |c|
  c.syntax = %{murano product}
  c.summary = %{About Product}
  c.description = %{Sub-commands for working with Products}

  c.action do |args, options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

#  vim: set ai et sw=2 ts=2 :
