module MCollective
  module Util
    class PuppetAgentMgr
      class MgrV3 < PuppetAgentMgr

        def initialize(configfile   = nil,
                       service_name = 'puppet',
                       testing      = false)
          @puppet_service = service_name
          unless testing || Puppet.settings.app_defaults_initialized?

            require 'puppet/util/run_mode'
            Puppet.settings.preferred_run_mode = :agent

            args = []
            (args << "--config=%s" % configfile) if configfile

            Puppet.settings.initialize_global_settings(args)
            Puppet.settings.initialize_app_defaults(
              Puppet::Settings.app_defaults_for_run_mode(Puppet.run_mode))
            # This check is to keep backwards compatibility
            # with Puppet versions < 3.5.0
            if Puppet.respond_to?(:base_context) \
                && Puppet.respond_to?(:push_context)
              Puppet.push_context(Puppet.base_context(Puppet.settings))
            end
          end
        end

        # enables the puppet agent, it can now start applying catalogs again
        def enable!
          raise "Already enabled" if enabled?
          File.unlink(Puppet[:agent_disabled_lockfile])
        end

        # disable the puppet agent
        def disable!(msg=nil)
          raise "Already disabled" unless enabled?
          msg ||= "Disabled using the Ruby API at %s" % Time.now.strftime("%c")
          atomic_file(Puppet[:agent_disabled_lockfile]) do |f|
            f.print(JSON.dump(:disabled_message => msg))
          end
          msg
        end

        # the current lock message, always "" on 2.0
        def lock_message
          if disabled?
            lock_data = JSON.parse(File.read(Puppet[:agent_disabled_lockfile]))
            return lock_data["disabled_message"]
          else
            return ""
          end
        end

        # is the agent disabled
        def disabled?
          File.exist?(Puppet[:agent_disabled_lockfile])
        end

        private

        def platform_applying?
          return false unless File.exist?(Puppet[:agent_catalog_run_lockfile])
          if File::Stat.new(Puppet[:agent_catalog_run_lockfile]).size > 0
            return has_process_for_pid?(
                      File.read(Puppet[:agent_catalog_run_lockfile]))
          end
          return false
        end
      end
    end
  end
end
