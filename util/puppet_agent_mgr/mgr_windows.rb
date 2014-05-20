module MCollective
  module Util
    class PuppetAgentMgr
      class MgrWindows < MgrV3

        # is the agent daemon currently running?
        # this will require win32/service
        def daemon_present?
          require 'win32/service'
          case Win32::Service.status(@puppet_service).current_state
          when "running", "continue pending", "start pending"
            true
          else
            false
          end
        rescue Win32::Service::Error
          false
        end

        # is the agent currently applying a catalog
        def applying?
          return false if disabled?
          begin
            pid = File.read(Puppet[:agent_catalog_run_lockfile])
            return has_process_for_pid?(pid)
          rescue Errno::ENOENT
            return false
          end
        rescue => e
          Log.warn("Could not determine if Puppet is applying a catalog: " \
                   "%s: %s: %s" % [e.backtrace.first, e.class, e.to_s])
          return false
        end

        def signal_running_daemon
          raise "Signalling the puppet daemon is not supported on Windows"
        end

        def has_process_for_pid?(pid)
          return false if pid.nil? or pid.empty?
          !!::Process.kill(0, Integer(pid))
        rescue Errno::EPERM
          true
        rescue Errno::ESRCH
          false
        end

        # the daemon doesn't interfere with background runs,
        # so they're always allowed
        def background_run_allowed?
          true
        end

        # this will require win32/process
        def run_in_background(clioptions, execute=true)
          require 'win32/process'
          options =["--onetime", "--color=false"].concat(clioptions)
          return options unless execute
          command = "puppet.bat agent #{options.join(' ')}"
          ::Process.create(:command_line   => command,
                           :creation_flags => ::Process::CREATE_NO_WINDOW)
        end

        # this will require win32/process
        def run_in_foreground(clioptions, execute=true)
          run_in_background(clioptions, execute)
        end
      end
    end
  end
end
