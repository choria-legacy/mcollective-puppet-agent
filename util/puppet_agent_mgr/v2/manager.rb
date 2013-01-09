module MCollective
  module Util
    module PuppetAgentMgr::V2
      class Manager
        include PuppetAgentMgr::Common

        if Puppet.features.microsoft_windows?
          require '%s/windows.rb' % File.dirname(__FILE__)
          include Windows
        else
          require '%s/unix.rb' % File.dirname(__FILE__)
          include Unix
        end

        def initialize(testing=false)
          unless testing
            $puppet_application_mode = Puppet::Util::RunMode[:agent]
            Puppet.settings.use :main, :agent
            Puppet.parse_config
          end
        end

        # enables the puppet agent, it can now start applying catalogs again
        def enable!
          raise "Already enabled" if enabled?
          File.unlink(Puppet[:puppetdlockfile])
        end

        # disable the puppet agent, on version 2.x the message is ignored
        def disable!(msg=nil)
          raise "Already disabled" unless enabled?
          File.open(Puppet[:puppetdlockfile], "w") { }

          ""
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
          ""
        end

        # is the agent disabled
        def disabled?
          if File.exist?(Puppet[:puppetdlockfile])
            if File::Stat.new(Puppet[:puppetdlockfile]).zero?
              return true
            end
          end

          false
        end

        # loads the summary file and makes sure that some keys are always present
        def load_summary
          summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}

          summary.merge!(YAML.load_file(Puppet[:lastrunfile])) if File.exist?(Puppet[:lastrunfile])

          summary["resources"] = {"failed"=>0, "changed"=>0, "total"=>0, "restarted"=>0, "out_of_sync"=>0}.merge!(summary["resources"])

          summary
        end
      end
    end
  end
end
