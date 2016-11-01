# encoding: utf-8
class MCollective::Application::Puppet<MCollective::Application
  description "Schedule runs, enable, disable and interrogate the Puppet Agent"

  usage <<-END_OF_USAGE
mco puppet [OPTIONS] [FILTERS] <ACTION> [CONCURRENCY|MESSAGE]
Usage: mco puppet <count|enable|status|summary>
Usage: mco puppet disable [message]
Usage: mco puppet runonce [PUPPET OPTIONS]
Usage: mco puppet resource type name property1=value property2=value
Usage: mco puppet runall [--rerun SECONDS] [PUPPET OPTIONS]

The ACTION can be one of the following:

    count    - return a total count of running, enabled, and disabled nodes
    enable   - enable the Puppet Agent if it was previously disabled
    disable  - disable the Puppet Agent preventing catalog from being applied
    resource - manage individual resources using the Puppet Type (RAL) system
    runall   - invoke a puppet run on matching nodes, making sure to only run
               CONCURRENCY nodes at a time. NOTE that any compound filters (-S)
               used with runall will be wrapped in parentheses and and'ed
               with "puppet().enabled=true".
    runonce  - invoke a Puppet run on matching nodes
    status   - shows a short summary about each Puppet Agent status
    summary  - shows resource and run time summaries
END_OF_USAGE

  option :force,
         :arguments   => ["--force"],
         :description => "Bypass splay options when running",
         :type        => :bool

  option :server,
         :arguments   => ["--server SERVER"],
         :description => "Connect to a specific server or port",
         :type        => String

  option :tag,
         :arguments   => ["--tags TAG", "--tag"],
         :description => "Restrict the run to specific tags",
         :type        => :array

  option :noop,
         :arguments   => ["--noop"],
         :description => "Do a noop run",
         :type        => :bool

  option :no_noop,
         :arguments   => ["--no-noop"],
         :description => "Do a run with noop disabled",
         :type        => :bool

  option :environment,
         :arguments   => ["--environment ENVIRONMENT"],
         :description => "Place the node in a specific environment for this run",
         :type        => String

  option :splay,
         :arguments   => ["--splay"],
         :description => "Splay the run by up to splaylimit seconds",
         :type        => :bool

  option :no_splay,
         :arguments   => ["--no-splay"],
         :description => "Do a run with splay disabled",
         :type        => :bool

  option :splaylimit,
         :arguments   => ["--splaylimit SECONDS"],
         :description => "Maximum splay time for this run if splay is set",
         :type        => Integer

  option :use_cached_catalog,
         :arguments   => ["--use_cached_catalog"],
         :description => "Use cached catalog for this run",
         :type        => :bool

  option :no_use_cached_catalog,
         :arguments   => ["--no-use_cached_catalog"],
         :description => "Do not use cached catalog for this run",
         :type        => :bool

  option :ignoreschedules,
         :arguments   => ["--ignoreschedules"],
         :description => "Disable schedule processing",
         :type        => :bool

  option :rerun,
         :arguments   => ["--rerun SECONDS"],
         :description => "When performing runall do so repeatedly with a minimum run time of SECONDS",
         :type        => Integer

  def post_option_parser(configuration)
    if ARGV.length >= 1
      configuration[:command] = ARGV.shift

      if arg = ARGV.shift
        if configuration[:command] == "runall"
          configuration[:concurrency] = Integer(arg)

        elsif configuration[:command] == "disable"
          configuration[:message] = arg

        elsif configuration[:command] == "resource"
          configuration[:type] = arg
          configuration[:name] = ARGV.shift
          configuration[:properties] = ARGV[0..-1]
        end
      end

      unless ["resource", "count", "runonce", "enable", "disable", "runall", "status", "summary"].include?(configuration[:command])
        raise_message(1)
      end
    else
      raise_message(2)
    end
  end

  def validate_configuration(configuration)
    if configuration[:force]
      raise_message(3) if configuration.include?(:splay)
      raise_message(4) if configuration.include?(:splaylimit)
    end

    if configuration[:command] == "runall"
      if configuration[:concurrency]
        raise_message(7) unless configuration[:concurrency] > 0
      else
        raise_message(5)
      end
    elsif configuration[:command] == "resource"
      raise_message(9) unless configuration[:type]
      raise_message(10) unless configuration[:name]
    end

    configuration[:noop] = false if configuration.include?(:no_noop)
    configuration[:splay] = false if configuration.include?(:no_splay)
    configuration[:use_cached_catalog] = false if configuration.include?(:no_use_cached_catalog)
  end

  def raise_message(message, *args)
    messages = {1 => "Action must be count, enable, disable, resource, runall, runonce, status or summary",
                2 => "Please specify a command.",
                3 => "Cannot set splay when forcing runs",
                4 => "Cannot set splaylimit when forcing runs",
                5 => "The runall command needs a concurrency limit",
                6 => "Do not know how to handle the '%s' command",
                7 => "The concurrency for the runall command has to be greater than 0",
                9 => "The resource command needs a type to operate on",
                10 => "The resource command needs a name to operate on"}

    raise messages[message] % args
  end

  def spark(histo, ticks=%w[▁ ▂ ▃ ▄ ▅ ▆ ▇])
    range = histo.max - histo.min

    if range == 0
      return ticks.first * histo.size
    end

    scale = ticks.size - 1
    distance = histo.max.to_f / scale

    histo.map do |val|
      tick = (val / distance).round
      tick = 0 if tick < 0
      tick = 1 if val > 0 && tick == 0 # show at least something for very small values

      ticks[tick]
    end.join
  end

  def shorten_number(number)
    number = Float(number)
    return "%0.1fm" % (number / 1000000) if number >= 1000000
    return "%0.1fk" % (number / 1000) if number >= 1000
    return "%0.1f" % number
  rescue
    "NaN"
  end

  def sparkline_for_field(results, field, bucket_count=20)
    buckets = Array.new(bucket_count) { 0 }
    values = []

    results.each do |result|
      if result[:statuscode] == 0
        values << result[:data][field]
      end
    end

    values.compact!

    return '' if values.empty?

    min = values.min
    max = values.max
    total = values.inject(:+)
    len = values.length
    avg = total.to_f / len

    bucket_size = ((max - min) / Float(bucket_count)) + 1

    unless max == min
      values.each do |value|
        bucket = Integer(((value - min) / bucket_size))
        buckets[bucket] += 1
      end
    end

    "%s  min: %-6s avg: %-6s max: %-6s" % [spark(buckets), shorten_number(min), shorten_number(avg), shorten_number(max)]
  end

  def client
    @client ||= rpcclient("puppet")
  end

  def extract_values_from_aggregates(aggregate_summary)
    counts = {}

    client.stats.aggregate_summary.each do |aggr|
      counts[aggr.result[:output]] = aggr.result[:value]
    end

    counts
  end

  def calculate_longest_hostname(results)
    results.map{|s| s[:sender]}.map{|s| s.length}.max
  end

  def display_results_single_field(results, field)
    return false if results.empty?

    sender_width = calculate_longest_hostname(results) + 3
    pattern = "%%%ds: %%s" % sender_width

    Array(results).each do |result|
      if result[:statuscode] == 0
        puts pattern % [result[:sender], result[:data][field]]
      else
        puts pattern % [result[:sender], MCollective::Util.colorize(:red, result[:statusmsg])]
      end
    end
  end

  def runonce_arguments
    arguments = {}

    [:use_cached_catalog, :force, :server, :noop, :environment, :splay, :splaylimit, :ignoreschedules].each do |arg|
      arguments[arg] = configuration[arg] if configuration.include?(arg)
    end

    arguments[:tags] = Array(configuration[:tag]).join(",") if configuration.include?(:tag)

    arguments
  end

  def resource_command
    arguments = {:name => configuration[:name], :type => configuration[:type]}

    configuration[:properties].each do |v|
      if v =~ /^(.+?)=(.+)$/
        arguments[$1] = $2
      else
        raise("Could not parse argument '%s'" % v)
      end
    end

    printrpc client.resource(arguments)

    printrpcstats :summarize => true

    halt client.stats
  end

  def runall_command(runner=nil)
    unless runner
      require 'mcollective/util/puppetrunner.rb'

      runner = MCollective::Util::Puppetrunner.new(client, configuration)
    end

    runner.logger do |msg|
      puts "%s: %s" % [Time.now.strftime("%F %T"), msg]
      ::MCollective::Log.debug(msg)
    end

    runner.runall(!!configuration[:rerun], configuration[:rerun])
  end

  def summary_command
    client.progress = false
    results = client.last_run_summary

    puts "Summary statistics for %d nodes:" % results.size
    puts
    puts "                  Total resources: %s" % sparkline_for_field(results, :total_resources)
    puts "            Out Of Sync resources: %s" % sparkline_for_field(results, :out_of_sync_resources)
    puts "                 Failed resources: %s" % sparkline_for_field(results, :failed_resources)
    puts "                Changed resources: %s" % sparkline_for_field(results, :changed_resources)
    puts "              Corrected resources: %s" % sparkline_for_field(results, :corrected_resources)
    puts "  Config Retrieval time (seconds): %s" % sparkline_for_field(results, :config_retrieval_time)
    puts "         Total run-time (seconds): %s" % sparkline_for_field(results, :total_time)
    puts "    Time since last run (seconds): %s" % sparkline_for_field(results, :since_lastrun)
    puts

    halt client.stats
  end

  def status_command
    display_results_single_field(client.status, :message)

    puts

    printrpcstats :summarize => true

    halt client.stats
  end

  def enable_command
    printrpc client.enable
    printrpcstats :summarize => true
    halt client.stats
  end

  def disable_command
    args = {}
    args[:message] = configuration[:message] if configuration[:message]

    printrpc client.disable(args)

    printrpcstats :summarize => true
    halt client.stats
  end

  def runonce_command
    printrpc client.runonce(runonce_arguments)

    printrpcstats

    halt client.stats
  end

  def count_command
    client.progress = false
    client.status

    counts = extract_values_from_aggregates(client.stats.aggregate_summary)

    puts "Total Puppet nodes: %d" % client.stats.okcount
    puts
    puts "          Nodes currently enabled: %d" % counts[:enabled].fetch("enabled", 0)
    puts "         Nodes currently disabled: %d" % counts[:enabled].fetch("disabled", 0)
    puts
    puts "Nodes currently doing puppet runs: %d" % counts[:applying].fetch(true, 0)
    puts "          Nodes currently stopped: %d" % counts[:applying].fetch(false, 0)
    puts
    puts "       Nodes with daemons started: %d" % counts[:daemon_present].fetch("running", 0)
    puts "    Nodes without daemons started: %d" % counts[:daemon_present].fetch("stopped", 0)
    puts "       Daemons started but idling: %d" % counts[:idling].fetch(true, 0)
    puts

    if client.stats.failcount > 0
      puts MCollective::Util.colorize(:red, "Failed to retrieve status of %d %s" % [client.stats.failcount, client.stats.failcount == 1 ? "node" : "nodes"])
    end

    halt client.stats
  end

  def main
    impl_method = "%s_command" % configuration[:command]

    if respond_to?(impl_method)
      send(impl_method)
    else
      raise_message(6, configuration[:command])
    end
  end
end
