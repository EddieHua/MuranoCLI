require 'MrMurano/commands/businessList'
#require 'MrMurano/commands/completion'
require 'MrMurano/commands/config'
require 'MrMurano/commands/domain'
require 'MrMurano/commands/init'
require 'MrMurano/commands/keystore'
require 'MrMurano/commands/login'
require 'MrMurano/commands/logs'
require 'MrMurano/commands/mock'
require 'MrMurano/commands/postgresql'
require 'MrMurano/commands/password'
require 'MrMurano/commands/settings'
require 'MrMurano/commands/show'
require 'MrMurano/commands/status'
require 'MrMurano/commands/sync'
require 'MrMurano/commands/tsdb'
require 'MrMurano/commands/usage'

# XXX: If this route, then 1p_legacy *HAS* to be in the Config files. (not on
# cmdline)
# Otherwise use an ENV var i suppose.
#if not ENV['1P_Legacy'].nil? then
if $cfg['tool.1p_legacy'] then
  require 'MrMurano/commands/cors' # future is only setting subcommand
  require 'MrMurano/commands/content-1p'
  require 'MrMurano/commands/product'
  require 'MrMurano/commands/productCreate'
  require 'MrMurano/commands/productDelete'
  require 'MrMurano/commands/productDevice'
  require 'MrMurano/commands/productDeviceIdCmds'
  require 'MrMurano/commands/productList'
  require 'MrMurano/commands/productWrite'
  require 'MrMurano/commands/solution'
  require 'MrMurano/commands/solutionCreate'
  require 'MrMurano/commands/solutionDelete'
  require 'MrMurano/commands/solutionList'

else
  require 'MrMurano/commands/content'
  require 'MrMurano/commands/devices'
  require 'MrMurano/commands/solution'
end

#  vim: set ai et sw=2 ts=2 :
