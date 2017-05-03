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
  require 'MrMurano/commands/1plegacy/content'
  require 'MrMurano/commands/1plegacy/product'
  require 'MrMurano/commands/1plegacy/productCreate'
  require 'MrMurano/commands/1plegacy/productDelete'
  require 'MrMurano/commands/1plegacy/productDevice'
  require 'MrMurano/commands/1plegacy/productDeviceIdCmds'
  require 'MrMurano/commands/1plegacy/productList'
  require 'MrMurano/commands/1plegacy/productWrite'
  require 'MrMurano/commands/1plegacy/solution'
  require 'MrMurano/commands/1plegacy/solutionCreate'
  require 'MrMurano/commands/1plegacy/solutionDelete'
  require 'MrMurano/commands/1plegacy/solutionList'

else
  require 'MrMurano/commands/content'
  require 'MrMurano/commands/devices'
  require 'MrMurano/commands/solution'
end

#  vim: set ai et sw=2 ts=2 :
