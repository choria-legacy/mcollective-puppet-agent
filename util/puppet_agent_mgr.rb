require File.expand_path(File.join(File.dirname(__FILE__),
                                   'puppet_server_address_validation.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   'puppet_agent_mgr', 'mgr_v2.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   'puppet_agent_mgr', 'mgr_v3.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   'puppet_agent_mgr', 'mgr_windows.rb'))


module MCollective
  module Util

    #
    ###   Manager parent class
    #

    class PuppetAgentMgr

      class NotImplementedError < StandardError
      end

      # manager cache
      @@the_manager = nil

      # returns the manager instance
      def self.manager(configfile   = nil,
                       service_name = 'puppet',
                       do_init      = false,
                       testing      = false)
        # we want a new instance for each spec
        if testing || do_init || !@@the_manager
          # TODO: get rid of the conditional require 'puppet'
          # we should get puppet if not testing
          require 'puppet' if not testing
          Log.debug("Creating a new instance of puppet agent manager: " \
                    "config file = %s, service name = %s, testing = %s" \
                    % [configfile, service_name, testing]) unless testing
          @@the_manager = from_version(configfile, service_name, testing)
        end
        @@the_manager
      end

      ###   manager factory (class method)

      class << self
        # NB: initilize() must be implemented by subclasses
        def from_version(configfile, service_name, testing)
          if Puppet.version =~ /^(\d+)/
            case $1
              when "2"
                raise "Window is not supported yet" if MCollective::Util.windows?
                return MgrV2.new(configfile, service_name, testing)
              when "3", "4", "5"
                if MCollective::Util.windows?
                  return MgrWindows.new(configfile, service_name, testing)
                else
                  return MgrV3.new(configfile, service_name, testing)
                end
              else
                raise "Cannot manage Puppet version %s" % $1
            end
          else
            raise "Cannot determine the Puppet major version"
          end
        end
      end

      ###   utility methods

      # all the managed resources
      def managed_resources
        # need to add some caching here based on mtime of the resources file
        return [] unless File.exist?(Puppet[:resourcefile])
        File.readlines(Puppet[:resourcefile]).map do |resource|
          resource.chomp
        end
      end

      # loads the summary file and ensures that some keys are always present
      def load_summary
        summary = {"changes" => {},
                   "time" => {},
                   "resources" => {},
                   "version" => {},
                   "events" => {}}
        if File.exist?(Puppet[:lastrunfile])
          summary.merge!(YAML.load_file(Puppet[:lastrunfile]))
        end
        summary["resources"] = \
          {"failed" => 0,
           "changed" => 0,
           "corrective_change" => 0,
           "total" => 0,
           "restarted" => 0,
           "out_of_sync" => 0}.merge!(summary["resources"])
        summary
      end

      # epoch time when the last catalog was applied
      def lastrun
        summary = load_summary
        summary_time = summary["time"].fetch("last_run", 0)
        begin
          return Integer(summary_time)
        rescue => e
          Log.warn("Couldn't parse %s (time from summary file); " \
                   "returning 0" % summary_time)
          0
        end
      end

      # how mnay of each type of resource is the node
      def managed_resource_type_distribution
        type_distribution = {}
        if File.exist?(Puppet[:resourcefile])
          File.readlines(Puppet[:resourcefile]).each do |line|
            type = line.split("[").first.split("::").map {
                      |i| i.capitalize}.join("::")
            type_distribution[type] ||= 0
            type_distribution[type] += 1
          end
        end
        type_distribution
      end

      # Reads the last run report and extracts the log lines
      #
      # @return [Array<Hash>]
      def last_run_logs
        return [] unless File.exists?(Puppet[:lastrunreport])

        report = YAML.load_file(Puppet[:lastrunreport])

        report.logs.map do |line|
          {
            "time_utc" => line.time.utc.to_i,
            "time" => line.time.to_i,
            "level" => line.level.to_s,
            "source" => line.source,
            "msg" => line.message.chomp
          }
        end
      end

      # covert seconds to human readable string
      def seconds_to_human(seconds)
        days = seconds / 86400
        seconds -= 86400 * days

        hours = seconds / 3600
        seconds -= 3600 * hours

        minutes = seconds / 60
        seconds -= 60 * minutes

        if days > 1
          return "%d days %d hours %d minutes %02d seconds" % [
                    days, hours, minutes, seconds]
        elsif days == 1
          return "%d day %d hours %d minutes %02d seconds" % [
                    days, hours, minutes, seconds]
        elsif hours > 0
          return "%d hours %d minutes %02d seconds" % [hours, minutes, seconds]
        elsif minutes > 0
          return "%d minutes %02d seconds" % [minutes, seconds]
        else
          return "%02d seconds" % seconds
        end
      end

      # simple utility to return a hash with lots of useful information
      # about the state of the agent
      def status
        the_last_run = lastrun
        status = {:applying => applying?,
                  :enabled => enabled?,
                  :daemon_present => daemon_present?,
                  :lastrun => the_last_run,
                  :idling => idling?,
                  :disable_message => lock_message,
                  :since_lastrun => (Time.now.to_i - the_last_run)}

        if !status[:enabled]
          status[:status] = "disabled"
        elsif status[:applying]
          status[:status] = "applying a catalog"
        elsif status[:idling]
          status[:status] = "idling"
        elsif !status[:applying]
          status[:status] = "stopped"
        end

        status[:message] = "Currently %s; last completed run %s ago" \
          % [status[:status], seconds_to_human(status[:since_lastrun])]
        status
      end

      # returns true if name is a single letter or an alphanumeric string
      def valid_name?(name)
        if name.length == 1
          return false unless name =~ /\A[a-zA-Z]\Z/
        else
          return false unless name =~ /\A[a-zA-Z0-9_]+\Z/
        end
        true
      end

      # validates arguments and returns the CL options to execute puppet
      def create_common_puppet_cli(noop=nil, tags=[], environment=nil,
                                   server=nil, splay=nil, splaylimit=nil,
                                   ignoreschedules=nil, use_cached_catalog=nil)
        opts = []
        tags = [tags].flatten.compact

        MCollective::Util::PuppetServerAddressValidation.validate_server(server)
        hostname, port = \
          MCollective::Util::PuppetServerAddressValidation.parse_name_and_port_of(server)

        if environment && !valid_name?(environment)
          raise("Invalid environment '%s' specified" % environment)
        end

        if splaylimit && !splaylimit.is_a?(Fixnum)
          raise("Invalid splaylimit '%s' specified" % splaylimit)
        end

        unless tags.empty?
          [tags].flatten.each do |tag|
            tag.split("::").each do |part|
              raise("Invalid tag '%s' specified" % tag) unless valid_name?(part)
            end
          end
          opts << "--tags %s" % tags.join(",")
        end

        opts << "--splay" if splay == true
        opts << "--no-splay" if splay == false
        opts << "--splaylimit %s" % splaylimit if splaylimit
        opts << "--noop" if noop == true
        opts << "--no-noop" if noop == false
        opts << "--environment %s" % environment if environment
        opts << "--server %s" % hostname if hostname
        opts << "--masterport %s" % port if port
        opts << "--ignoreschedules" if ignoreschedules
        opts << "--use_cached_catalog" if use_cached_catalog == true
        opts << "--no-use_cached_catalog" if use_cached_catalog == false
        opts
      end

      def run_in_foreground(clioptions, execute=true)
        options = ["--onetime", "--no-daemonize", "--color=false",
                   "--show_diff", "--verbose"].concat(clioptions)
        return options unless execute
        %x[puppet agent #{options.join(' ')}]
      end

      def run_in_background(clioptions, execute=true)
        options =["--onetime",
                  "--daemonize", "--color=false"].concat(clioptions)
        return options unless execute
        %x[puppet agent #{options.join(' ')}]
      end

      # do a run based on the following options:
      #
      # :foreground_run  - runs in the foreground a --test run
      # :foreground_run  - runs in the foreground a --onetime --no-daemonize
      #                      --show_diff --verbose run
      # :signal_daemon   - if the daemon is running, sends it USR1 to wake it up
      # :noop            - enables or disabled noop mode based on true/false
      # :tags            - an array of tags to limit the run to
      # :environment     - the environment to run
      # :server          - puppet master to use, can be some.host or some.host:port
      # :splay           - enables or disables splay based on true/false
      # :splaylimit      - set the maximum splay time
      # :ignoreschedules - instructs puppet to ignore any defined schedules
      #
      # else a single background run will be attempted but this will fail if
      # an idling daemon is present and :signal_daemon was false
      def runonce!(options={})
        valid_options = [:noop, :signal_daemon, :foreground_run, :tags,
                         :environment, :server, :splay, :splaylimit,
                         :options_only, :ignoreschedules, :use_cached_catalog]

        options.keys.each do |opt|
          unless valid_options.include?(opt)
            raise("Unknown option %s specified" % opt)
          end
        end

        if applying?
          raise "Puppet is currently applying a catalog, cannot run now"
        end

        if disabled?
          raise "Puppet is disabled, cannot run now"
        end

        splay           = options.fetch(:splay, nil)
        splaylimit      = options.fetch(:splaylimit, nil)
        noop            = options.fetch(:noop, nil)
        signal_daemon   = options.fetch(:signal_daemon,
                                        Util.str_to_bool(Config.instance.pluginconf.fetch("puppet.signal_daemon", "true")))
        foreground_run  = options.fetch(:foreground_run, false)
        environment     = options.fetch(:environment, nil)
        server          = options.fetch(:server, nil)
        ignoreschedules = options.fetch(:ignoreschedules, nil)
        use_cached_catalog = options.fetch(:use_cached_catalog, nil)
        tags            = [ options[:tags] ].flatten.compact

        clioptions = create_common_puppet_cli(noop, tags, environment,
                                              server, splay, splaylimit,
                                              ignoreschedules, use_cached_catalog)

        if idling? && signal_daemon && !clioptions.empty?
          raise "Cannot specify any custom puppet options " \
                "when the daemon is running"
        end

        if foreground_run
          if options[:options_only]
            return :foreground_run, run_in_foreground(clioptions, false)
          end
          return run_in_foreground(clioptions)
        elsif idling? && signal_daemon
          return :signal_running_daemon, clioptions if options[:options_only]
          return signal_running_daemon
        else
          raise "Cannot run when the agent is running" if applying?
          return :run_in_foreground, run_in_foreground(clioptions, false)
        end
      end

      def atomic_file(file)
        tempfile = Tempfile.new(File.basename(file), File.dirname(file))
        yield(tempfile)
        tempfile.close
        File.rename(tempfile.path, file)
      end

      ###   Unix methods (Windows manager subclass must override)

      # is the agent daemon currently in the unix process list?
      def daemon_present?
        if File.exist?(Puppet[:pidfile])
          return has_process_for_pid?(File.read(Puppet[:pidfile]))
        end
        false
      end

      # is the agent currently applying a catalog
      def applying?
        begin
          platform_applying?
        rescue NotImplementedError
          raise
        rescue => e
          Log.warn("Could not determine if Puppet is applying a catalog: " \
                   "%s: %s: %s" % [e.backtrace.first, e.class, e.to_s])
          false
        end
      end

      def signal_running_daemon
        pid = File.read(Puppet[:pidfile])

        if has_process_for_pid?(pid)
          begin
            ::Process.kill("USR1", Integer(pid))
          rescue Exception => e
            raise "Failed to signal the puppet agent at pid " \
                  "%s: %s" % [pid, e.to_s]
          end
        else
          run_in_background
        end
      end

      def has_process_for_pid?(pid)
        !!::Process.kill(0, Integer(pid)) rescue false
      end

      ###   state of the world

      # is a catalog being applied rigt now?
      def stopped?
        !applying?
      end

      # is the daemon running but not applying a catalog
      def idling?
        daemon_present? && !applying?
      end

      # is the agent enabled
      def enabled?
        !disabled?
      end

      # is a background run allowed? by default it's only allowed if the
      # daemon isn't present but can be overridden
      def background_run_allowed?
        !daemon_present?
      end


      # seconds since the last catalog was applied
      def since_lastrun
        (Time.now - lastrun).to_i
      end

      # if a resource is being managed, resource in the syntax File[/x] etc
      def managing_resource?(resource)
        if resource =~ /^(.+?)\[(.+)$/
          managed_resources.include?([$1.downcase, $2].join("["))
        else
          raise "Invalid resource name %s" % resource
        end
      end

      # how many resources are managed
      def managed_resources_count
        managed_resources.size
      end

      ###   methods that must be implemented by subclasses

      def initialize(*args)
        raise NotImplementedError, "Must use PuppetAgentMgr.manager"
      end

      # enables the puppet agent, it can now start applying catalogs again
      def enable!
        raise NotImplementedError, "Not implemented by subclass"
      end

      # disable the puppet agent, on version 2.x the message is ignored
      def disable!(msg=nil)
        raise NotImplementedError, "Not implemented by subclass"
      end

      # the current lock message, always "" on 2.0
      def lock_message
        raise NotImplementedError, "Not implemented by subclass"
      end

      # is the agent disabled
      def disabled?
        raise NotImplementedError, "Not implemented by subclass"
      end

      ###   private methods

      private

      def platform_applying?
        raise NotImplementedError, "Not implemented by subclass"
      end

    end
  end
end
