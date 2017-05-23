
module MrMurano
  class Hooked
    include Verbose
    attr :section

    def initialize(section)
      @section = section
    end

    def check_run_pre_hook
      prehook = $cfg["#{section}.pre-hook"]
      return if prehook.nil?
      return if prehook.empty?
      verbose "calling pre-hook: #{prehook}"
      system(prehook)
    end

    def check_run_post_hook
      posthook = $cfg["#{section}.post-hook"]
      return if posthook.nil?
      return if posthook.empty?
      verbose "calling post-hook: #{posthook}"
      system(posthook)
    end

  end
end

module Commander
  class Runner
    alias :old_run_active_command :run_active_command
    def run_active_command
      section = active_command.name
      hooked = MrMurano::Hooked.new(section)
      hooked.check_run_pre_hook

      begin
        old_run_active_command
      rescue MrMurano::ConfigError => err
        puts err.message
        exit 1
      rescue StandardError => err
        raise
      end

      hooked.check_run_post_hook
    end

    alias :old_parse_global_options :parse_global_options
    def parse_global_options
      defopts = ($cfg["#{active_command.name}.options"] or '').split
      @args.push( *defopts )
      old_parse_global_options
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
