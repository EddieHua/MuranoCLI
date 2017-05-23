require 'uri'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SyncUpDown'

module MrMurano
  class SolutionBase
    def initialize
      @sid = $cfg['solution.id']
      raise MrMurano::ConfigError.new("No solution!") if @sid.nil?
      @uriparts = [:solution, @sid]
      @itemkey = :id
      @project_section = nil
    end

    include Http
    include Verbose

    ## Generate an endpoint in Murano
    # Uses the uriparts and path
    # @param path String: any additional parts for the URI
    # @return URI: The full URI for this enpoint.
    def endPoint(path='')
      parts = ['https:/', $cfg['net.host'], 'api:1'] + @uriparts
      s = parts.map{|v| v.to_s}.join('/')
      URI(s + path.to_s)
    end
    # …

    include SyncUpDown
  end

  class Solution < SolutionBase
    def version
      get('/version')
    end

    def info
      get()
    end

    def list
      get('/')
    end

    def log
      get('/logs')
    end

    def usage
      get('/usage')
    end

  end

end

#  vim: set ai et sw=2 ts=2 :
