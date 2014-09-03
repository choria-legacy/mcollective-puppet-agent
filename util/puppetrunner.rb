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

        runhosts(hosts)
      end

      def runhosts(hosts)
        # copy the host list so we can manipulate it
        host_list = hosts.clone
        # determine the state of the network based on the supplied host list
        running = find_applying_nodes(host_list)
        while !host_list.empty?
          # Check if we have room in the running bucket
          if running.size < @concurrency
            # if we have room add another host to the bucket
            host = host_list.pop
            # check if host is already in a running state
            if !running.select{ |running_host| running_host[:name] == host }.empty?
              # put it back in the host list if it is, save it for later
              host_list.push(host)
            else
              # kick a host, put it in the running bucket
              running << {:name => host, :initiated_at => runhost(host), :checks => 0}
            end
          else
            # we are at concurrency, wait a second to give some time for something
            # to happen
            sleep 1
            # determine the state of the network based on the supplied host list
            running = find_applying_nodes(hosts, running)
          end
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
      def find_applying_nodes(hosts, initiated = [])
        @client.filter["identity"].clear
        hosts.each do |host|
          @client.identity_filter(host)
        end

        initiated_host_names = initiated.map{ |h| h[:name] }

        result = @client.status.map do |r|
          sender = r[:sender]
          # check the value of applying as defined in the agent ddl
          # NOTE: Only using this method can cause a race condition since it
          # ignores the "asked to run but not yet started" state.
          if r[:data][:applying] == true
            if r[:data][:initiated_at]
              {:name => sender,:initiated_at => r[:data][:initiated_at], :checks => 0}
            else
              {:name => sender, :initiated_at => 0, :checks => 0}
            end
          else
            if index = initiated_host_names.index(sender)
              if initiated[index][:checks] >= 5
                log("Host #{sender} did not move into an applying state. Skipping.")
                nil
              else
                # Here we check the "asked to run but not yet started" state.
                if initiated[index][:initiated_at] > r[:data][:lastrun].to_i
                  # increment the check counter. We give it 5 seconds to transition
                  # into the applying state
                  initiated[index][:checks] += 1
                  # sender has been asked to run but hasn't started yet
                  initiated[index]
                end
              end
            end
          end
        end.reject { |val| !val }
      end

      def runonce_arguments
        arguments = {}

        [:force, :server, :noop, :environment, :splay, :splaylimit, :ignoreschedules].each do |arg|
          arguments[arg] = @configuration[arg] if @configuration.include?(arg)
        end

        arguments[:tags] = Array(@configuration[:tag]).join(",") if @configuration.include?(:tag)

        arguments
      end
    end
  end
end
