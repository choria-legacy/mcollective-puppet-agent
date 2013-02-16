module MCollective
  module Util
    module PuppetAgentMgr::V3
      class Manager
        if Puppet.features.microsoft_windows?
          require '%s/windows.rb' % File.dirname(__FILE__)
          include Windows
        else
          require '%s/unix.rb' % File.dirname(__FILE__)
          include Unix
        end

        include PuppetAgentMgr::Common

        def initialize(configfile=nil, testing=false)
          unless testing || Puppet.settings.app_defaults_initialized?
            require 'puppet/util/run_mode'
            Puppet.settings.preferred_run_mode = :agent

            args = []
            (args << "--config=%s" % configfile) if configfile

            Puppet.settings.initialize_global_settings(args)
            Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(Puppet.run_mode))
          end
        end

        # enables the puppet agent, it can now start applying catalogs again
        def enable!
          raise "Already enabled" if enabled?
          File.unlink(Puppet[:agent_disabled_lockfile])
        end

        # disable the puppet agent, on version 2.x the message is ignored
        def disable!(msg=nil)
          raise "Already disabled" unless enabled?

          msg = "Disabled using the Ruby API at %s" % Time.now.strftime("%c") unless msg

          atomic_file(Puppet[:agent_disabled_lockfile]) do |f|
            f.print(JSON.dump(:disabled_message => msg))
          end

          msg
        end

        # all the managed resources
        def managed_resources
          # need to add some caching here based on mtime of the resources file
          return [] unless File.exist?(Puppet[:resourcefile])

          File.readlines(Puppet[:resourcefile]).map do |resource|
            resource.chomp
          end
        end

        # epoch time when the last catalog was applied
        def lastrun
          summary = load_summary

          Integer(summary["time"].fetch("last_run", 0))
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
      end
    end
  end
end
