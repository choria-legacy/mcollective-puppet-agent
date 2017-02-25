module MCollective
  module Agent
    class Puppet<RPC::Agent
      activate_when do
        require 'mcollective/util/puppet_agent_mgr'
        true
      end

      def startup_hook
        configfile = @config.pluginconf.fetch("puppet.config", nil)

        @puppet_command = @config.pluginconf.fetch("puppet.command", default_agent_command)
        @puppet_service = @config.pluginconf.fetch("puppet.windows_service", "puppet")
        @puppet_splaylimit = Integer(@config.pluginconf.fetch("puppet.splaylimit", 30))
        @puppet_splay = Util.str_to_bool(@config.pluginconf.fetch("puppet.splay", "true"))
        @puppet_agent = Util::PuppetAgentMgr.manager(configfile, @puppet_service)
      end

      # Determines the default command to run for puppet agent
      #
      # Return the puppet script to execute on the local platform.
      def default_agent_command
        if Util.windows?
          "puppet.bat"
        else
          "puppet"
        end + " agent"
      end

      def run(command, options)
        if MCollective::Util.windows?
          require 'win32/process'
          # If creating the process doesn't outright fail, assume everything
          # was okay. The caller wants to know our exit code, so we'll just use
          # 0 or 1.
          begin
            ::Process.create(:command_line => command,
                             :creation_flags => ::Process::CREATE_NEW_CONSOLE)
            0
          rescue Exception => e
            Log.warn("Failed to execute #{command} - #{e}")
            1
          end
        else
          # On Unices double fork and exec to run puppet in a disowned child
          child = fork {
            # If relying on Puppet on PATH, ensure the default AIO path is included.
            # On Windows, the MSI adds Puppet to the PATH.
            if command.start_with?("puppet ")
              ENV["PATH"] += ":/opt/puppetlabs/bin"
            end

            grandchild = fork {
              exec command
            }
            if grandchild != nil
              ::Process.detach(grandchild)
            end
          }
          return 1 if child.nil?
          ::Process.detach(child)
          return 0
        end
      end

      action "disable" do
        begin
          request_msg = request.fetch(:message, "Disabled via MCollective by " \
                                      "%s at %s" % [request.caller,
                                                    Time.now.strftime("%F %R")])
          agent_msg = @puppet_agent.disable!(request_msg)
          reply[:status] = "Succesfully locked the Puppet agent: %s" % agent_msg
        rescue => e
          reply.fail(reply[:status] = "Could not disable Puppet: %s" % e.to_s)
        end

        reply[:enabled] = @puppet_agent.status[:enabled]
      end

      action "enable" do
        begin
          @puppet_agent.enable!
          reply[:status] = "Succesfully enabled the Puppet agent"
        rescue => e
          reply.fail(reply[:status] = "Could not enable Puppet: %s" % e.to_s)
        end

        reply[:enabled] = @puppet_agent.status[:enabled]
      end

      action "last_run_summary" do
        summary = @puppet_agent.load_summary

        if request[:logs]
          reply[:logs] = @puppet_agent.last_run_logs
        else
          reply[:logs] = {}
        end

        reply[:type_distribution]     = @puppet_agent.managed_resource_type_distribution
        reply[:out_of_sync_resources] = summary["resources"].fetch("out_of_sync", 0)
        reply[:failed_resources]      = summary["resources"].fetch("failed", 0)
        reply[:corrected_resources]   = summary["resources"].fetch("corrective_change", 0)
        reply[:changed_resources]     = summary["resources"].fetch("changed", 0)
        reply[:total_resources]       = summary["resources"].fetch("total", 0)
        reply[:total_time]            = summary["time"].fetch("total", 0)
        reply[:config_retrieval_time] = summary["time"].fetch("config_retrieval", 0)
        reply[:lastrun]               = Integer(summary["time"].fetch("last_run", 0))
        reply[:since_lastrun]         = Integer(Time.now.to_i - reply[:lastrun])
        reply[:config_version]        = summary["version"].fetch("config", "unknown")
        reply[:summary]               = summary
      end

      action "status" do
        status = @puppet_agent.status

        @reply.data.merge!(status)
      end

      action "resource" do
        allow_managed_resources_management = Util.str_to_bool(
          @config.pluginconf.fetch("puppet.resource_allow_managed_resources", "false"))
        resource_types_whitelist = \
          @config.pluginconf.fetch("puppet.resource_type_whitelist", nil)
        resource_types_blacklist = \
          @config.pluginconf.fetch("puppet.resource_type_blacklist", nil)

        if resource_types_whitelist && resource_types_blacklist
          reply.fail!("You cannot specify both puppet.resource_type_whitelist " \
                      "and puppet.resource_type_blacklist in the config file")
        end

        # if 'none' is specified whitelist nothing
        resource_types_whitelist = "" if resource_types_whitelist == "none"

        # if neither is specified default to whitelisting
        # nothing thus denying everything
        if resource_types_blacklist.nil? && resource_types_whitelist.nil?
          resource_types_whitelist = ""
        end


        params = request.data.clone
        params.delete(:process_results)
        type = params.delete(:type).downcase
        resource_name = "%s[%s]" % [type.to_s.capitalize, params[:name]]

        resource_names_whitelist = \
          @config.pluginconf.fetch("puppet.resource_name_whitelist.%s" % type, nil)
        resource_names_blacklist = \
          @config.pluginconf.fetch("puppet.resource_name_blacklist.%s" % type, nil)

        if resource_names_whitelist && resource_names_blacklist
          reply.fail!("You cannot specify both puppet.resource_name_whitelist.%s " \
                      "and puppet.resource_name_blacklist.%s in the config file" % [type, type])
        end

        if resource_types_blacklist
          if resource_types_blacklist.split(",").include?(type)
            reply.fail!("The %s type is listed in the type blacklist" % type)
          end
        elsif resource_types_whitelist
          unless resource_types_whitelist.split(",").include?(type)
            reply.fail!("The %s type is not listed in the type whitelist" % type)
          end
        end

        if resource_names_blacklist
          if resource_names_blacklist.split(",").include?(params[:name])
            reply.fail!("The %s name is listed in the name blacklist" % params[:name])
          end
        elsif resource_names_whitelist
          unless resource_names_whitelist.split(",").include?(params[:name])
            reply.fail!("The %s name is not listed in the name whitelist" % params[:name])
          end
        end

        if allow_managed_resources_management \
           || !@puppet_agent.managing_resource?(resource_name)
          resource = ::Puppet::Type.type(type).new(params)
          report = ::Puppet::Transaction::Report.new(:mcollective)
          ::Puppet::Util::Log.newdestination(report)
          catalog = ::Puppet::Resource::Catalog.new
          catalog.add_resource(resource)
          catalog.apply(:report => report)

          if report.logs.empty?
            reply[:result] = "no output produced"
          else
            reply[:result] = report.logs.join("\n")
          end

          reply[:changed] = report.resource_statuses[resource_name].changed

          if report.resource_statuses[resource_name].failed
            reply.fail!("Failed to apply %s: %s" % [resource_name, reply[:result]])
          end
        else
          reply.fail!("Puppet is managing the resource '%s', " \
                      "refusing to create conflicting states" % resource_name)
        end
      end

      action "runonce" do
        args = {}

        if @puppet_agent.disabled?
          message = @puppet_agent.lock_message

          if message == ""
            reply.fail!(reply[:summary] = "Puppet is disabled")
          else
            reply.fail!(reply[:summary] = "Puppet is disabled: '%s'" % message)
          end
        end

        args[:options_only] = true
        args[:noop] = request[:noop] if request.include?(:noop)
        args[:environment] = request[:environment] if request[:environment]
        if request[:server]
          if Util.str_to_bool(@config.pluginconf.fetch("puppet.allow_server_override","false"))
            args[:server] = request[:server]
          else
            reply.fail!(reply[:summary] = "Passing 'server' option is not allowed in module configuration")
          end
        end
        args[:tags] = request[:tags].split(",").map{|t| t.strip} if request[:tags]
        args[:ignoreschedules] = request[:ignoreschedules] if request[:ignoreschedules]
        args[:signal_daemon] = false if MCollective::Util.windows?
        args[:use_cached_catalog] = request[:use_cached_catalog] if request.include?(:use_cached_catalog)

        # we can only pass splay arguments if the daemon isn't in signal mode :(
        signal_daemon = Util.str_to_bool(@config.pluginconf.fetch("puppet.signal_daemon","true"))
        unless @puppet_agent.status[:daemon_present] && signal_daemon
          if request[:force] == true
            # forcing implies --no-splay
            args[:splay] = false
          else
            # respect splay options
            args[:splay] = request[:splay] if request.include?(:splay)
            args[:splaylimit] = request[:splaylimit] if request.include?(:splaylimit)

            unless args.include?(:splay)
              args[:splay] = @puppet_splay
            end

            if !args.include?(:splaylimit) && args[:splay]
              args[:splaylimit] = @puppet_splaylimit
            end
          end
        end

        begin
          run_method, options = @puppet_agent.runonce!(args)
        rescue => e
          reply.fail!(reply[:summary] = e.to_s)
        end

        command = [@puppet_command].concat(options).join(" ")

        case run_method
          when :run_in_foreground
            Log.debug("Initiating a puppet agent run using the command: %s" % command)

            exitcode = run(command, {
              :stdout => :summary,
              :stderr => :summary,
              :chomp => true,
            })

            unless exitcode == 0
              reply.fail!(reply[:summary] = "Puppet command '%s' had exit " \
                                            "code %d, expected 0" \
                                            % [command, exitcode])
            else
              reply[:summary] = "Started a Puppet run using the " \
                                "'%s' command" % command
            end

          when :signal_running_daemon
            Log.debug("Signaling the running Puppet agent " \
                      "to start an immediate run")
            @puppet_agent.signal_running_daemon
            reply[:summary] = "Signalled the running Puppet Daemon"

          else
            reply.fail!(reply[:summary] = "Do not know how to do puppet runs " \
                                          "using method %s" % run_method)
        end
        reply[:initiated_at] = Time.now.to_i
      end
    end
  end
end
