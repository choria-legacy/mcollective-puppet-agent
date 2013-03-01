module MCollective
  module Util
    class Puppetrunner
      attr_reader :client, :concurrency, :configuration

      def initialize(client, configuration)
        @client = client
        @concurrency = configuration.fetch(:concurrency, 0)
        @configuration = configuration

        raise("Concurrency has to be > 0") unless @concurrency > 0
        raise("The compound filter should be empty") unless client.filter["compound"].empty?

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
        runcount = 0

        hosts.each_with_index do |host, count|
          if runcount == 0
            hosts_left = hosts.size - count
            log("%d out of %d hosts left to run in this iteration" % [hosts_left, hosts.size]) if hosts_left > 0 && count > 0

            runcount = wait_for_applying_nodes - 1
          else
            runcount -= 1
          end

          runhost(host)

          sleep 0.5
        end
      end

      def runhost(host)
        client.discover :nodes => host
        result = client.runonce(runonce_arguments.merge({:force => true}))
        client.reset

        begin
          if result[0][:statuscode] == 0
            log("%s schedule status: %s" % [host, result[0][:data][:summary]])
          else
            log("%s schedule status: %s" % [host, result[0][:statusmsg]])
          end
        rescue
          log("%s returned an unknown result: %s" % [host, result.inspect])
        end
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
        @client.filter["compound"].clear
        @client.compound_filter("puppet().enabled=true")
        @client.discover.clone
      end

      def wait_for_applying_nodes
        @client.filter["compound"].clear
        @client.compound_filter("puppet().applying=true")

        loop do
          @client.reset
          applying = client.discover.size

          if applying < @concurrency
            return @concurrency - applying
          end

          log("Currently %d %s applying the catalog; waiting for less than %d" % [applying, applying > 1 ? "nodes" : "node", @concurrency])
          sleep 1
        end
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
