module MCollective
  module Util
    class PuppetAgentMgr
      class MgrV2 < PuppetAgentMgr

        def initialize(configfile   = nil,
                       service_name = nil,
                       testing      = false)
          unless testing
            $puppet_application_mode = Puppet::Util::RunMode[:agent]
            Puppet.settings.use :main, :agent
            Puppet.settings.set_value(:config, configfile, :cli) if configfile
            Puppet.parse_config
          end
        end

        # enables the puppet agent, it can now start applying catalogs again
        def enable!
          raise "Already enabled" if enabled?
          File.unlink(Puppet[:puppetdlockfile])
        end

        # disable the puppet agent, the message is ignored
        def disable!(msg=nil)
          raise "Already disabled" unless enabled?
          File.open(Puppet[:puppetdlockfile], "w") { }
          ""
        end

        # the current lock message, always "" on 2.0
        def lock_message
          ""
        end

        # is the agent disabled
        def disabled?
          if File.exist?(Puppet[:puppetdlockfile])
            if File::Stat.new(Puppet[:puppetdlockfile]).zero?
              return true
            end
          end
          return false
        end

        private

        def platform_applying?
          return false unless File.exist?(Puppet[:puppetdlockfile])
          if File::Stat.new(Puppet[:puppetdlockfile]).size > 0
            return has_process_for_pid?(File.read(Puppet[:puppetdlockfile]))
          end
          return false
        end
      end
    end
  end
end
