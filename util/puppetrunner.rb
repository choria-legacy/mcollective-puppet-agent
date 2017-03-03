module MCollective
  module Util
    class Puppetrunner
      attr_reader :client, :concurrency, :configuration

      def initialize(client, configuration)
        @client = client
        @concurrency = configuration.fetch(:concurrency, 0)
        @configuration = configuration

        raise("Concurrency has to be > 0") unless @concurrency > 0

        setup
      end

      def runall(rerun=false, rerun_min_time=3600)
        if rerun
          runall_forever(rerun_min_time)
        else
          runall_once
        end
      end

      def runall_forever(min_time, maxtimes=1.0/0.0)
        log("Performing ongoing Puppet run management with a minimum runtime of %d seconds between loops" % min_time)

        (1..maxtimes).each do
          start_time = Time.now

          begin
            runall_once
          rescue => e
            log("Running nodes failed: %s: %s: %s" % [e.backtrace.first, e.class, e.to_s])
          end

          run_time = Time.now - start_time

          if run_time <= min_time
            sleep_time = min_time - run_time

            log("Running all hosts took %d seconds; sleeping for %d seconds due to minimum run time configuration of %d seconds" % [run_time, sleep_time, min_time])

            sleep sleep_time
          else
            log("Running all hosts took %d seconds; starting a new loop immediately due to minimum run time configuration of %d secnods" % [run_time, min_time])
          end
        end
      end

      def runall_once
        log("Running all nodes with a concurrency of %s" % @concurrency)
        log("Discovering enabled Puppet nodes to manage")

        hosts = find_enabled_nodes

        log("Found %d enabled %s" % [hosts.size, hosts.size == 1 ? "node" : "nodes"])
        Log.debug("Enabled nodes are #{hosts.inspect}")

        runhosts(hosts)
      end

      def runhosts(hosts)
        # copy the host list so we can manipulate it
        host_list = hosts.clone

        # determine the initial state of the network based on the supplied host list
        running = find_applying_nodes(host_list)

        while !host_list.empty?
          # clone list so we can safely remove items host_list
          working_list = host_list.clone

          working_list.each do |host|
            if running.size >= @concurrency
              # we do not have room for another running host
              break
            end
            # check if host is already in a running state
            Log.debug("Checking #{host}")
            Log.debug(" -- running: %d, concurrency: %d" % [running.size, @concurrency])
            if running.find{ |running_host| running_host[:name] == host }
              # already in a running state, leave it for now
              Log.debug("#{host} is already being tracked, skipping it")
            else
              # host is not running - kick it, put it in the running bucket
              Log.debug("Triggering #{host}")
              initiated_at = runhost(host)
              running << make_status(host, initiated_at)
              host_list.delete(host)
              next
            end
          end

          Log.debug("Sleeping")
          # wait a second to give some time for something to happen
          sleep 1
          # update our view of the network
          running = find_applying_nodes(hosts, running)
        end

        log("Iteration complete. Initiated a Puppet run on #{hosts.size} nodes.")
      end

      def runhost(host)
        client.discover :nodes => host
        result = client.runonce(runonce_arguments.merge({:force => true}))
        client.reset

        if result.empty?
          log("%s did not return a result" % [host])
          return 0
        end

        begin
          if result[0][:statuscode] == 0
            log("%s schedule status: %s" % [host, result[0][:data][:summary]])
          else
            log("%s schedule status: %s" % [host, result[0][:statusmsg]])
          end
        rescue
          log("%s returned an unknown result: %s" % [host, result.inspect])
        end
        result[0][:data][:initiated_at].to_i || 0
      end

      def setup
        @client.progress = false
      end

      def logger(&blk)
        @logger = blk
      end

      def log(msg)
        raise("Cannot log, no logger has been defined") unless @logger

        @logger.call(msg)
      end

      def find_enabled_nodes
        unless @client.filter["compound"].empty?
          # munge the filter to and it with checking for enabled nodes
          log("Modifying user-specified filter: and'ing with 'puppet().enabled=true'")
          filter = @client.filter["compound"].clone
          filter[0].unshift("(" => "(")
          filter[0].unshift("and" => "and")
          filter[0].unshift({"fstatement" => {
                               "operator" => "==",
                               "params" => nil,
                               "r_compare" => "true",
                               "name" => "puppet",
                               "value" => "enabled"}
                            })
          filter[0].push({")" => ")"})
          @client.filter["compound"].clear
          @client.filter["compound"] = filter
        else
          @client.filter["compound"].clear
          @client.compound_filter("puppet().enabled=true")
        end
        @client.discover.clone
      end

      # Get a list of nodes that are possibly applying
      def find_applying_nodes(hosts, statuses = [])
        Log.debug("checking applying status of #{hosts.inspect}")
        @client.filter["identity"].clear
        hosts.each do |host|
          @client.identity_filter(host)
        end

        results = @client.status

        hosts.each do |host|
          result = results.select { |r| r[:sender] == host }.first
          status = statuses.select { |s| s[:name] == host }.first

          unless status
            status = make_status(host)
            statuses << status
          end

          if result
            # check the value of applying as defined in the agent ddl
            if result[:data][:applying] == true
              # we're applying
              if result[:data][:initiated_at]
                # it's a new agent, we can record when it started
                Log.debug("#{host} run was started at #{result[:data][:initiated_at]}")
                status[:initiated_at] = result[:data][:initiated_at]
              else
                Log.debug("#{host} run started")
              end
            else
              # Here we check the "asked to run but not yet started" state.
              if result[:data][:lastrun].to_i >= status[:initiated_at]
                Log.debug("#{host} run completed")
                # The node has finished applying, remove from the running set
                statuses.reject! { |s| s[:name] == host }
                next
              else
                # We haven't started yet that we can see, increment the check counter
                status[:checks] += 1
                Log.debug("#{host} starting, checks #{status[:checks]}")
              end
            end
          else
            # We didn't get a result from this host, log and record a check happened
            log("Host #{host} did not respond to the status action.")
            status[:no_response] += 1
          end

          if status[:no_response] >= 5
            # If we missed many responses to status, assume it's a dead node
            log("Host #{host} failed to respond multiple times. Skipping.")
            statuses.reject! { |s| s[:name] == host }
          end

          if status[:checks] >= 5
            # If we hit more than 5 checks, assume it couldn't start
            log("Host #{host} did not move into an applying state. Skipping.")
            statuses.reject! { |s| s[:name] == host }
          end
        end

        return statuses
      end

      def runonce_arguments
        arguments = {}

        [:force, :server, :noop, :environment, :splay, :splaylimit, :ignoreschedules].each do |arg|
          arguments[arg] = @configuration[arg] if @configuration.include?(arg)
        end

        arguments[:tags] = Array(@configuration[:tag]).join(",") if @configuration.include?(:tag)

        arguments
      end

      private

      # create the status objects managed by find_applying_nodes and runhosts
      def make_status(host, initiated_at = 0)
        status = {
          :name => host,
          :initiated_at => initiated_at,
          :checks => 0,
          :no_response => 0,
        }

        return status
      end
    end
  end
end
