metadata :name => "puppet",
         :description => "Run Puppet agent, get its status, and enable/disable it",
         :author => "R.I.Pienaar <rip@devco.net>",
         :license => "ASL2.0",
         :version => "1.13.0",
         :url => "http://puppetlabs.com",
         :timeout => 20

requires :mcollective => "2.2.1"

action "resource", :description => "Evaluate Puppet RAL resources" do
    display :always

    input :name,
          :prompt      => "Name",
          :description => "Resource Name",
          :type        => :string,
          :validation  => '^.+$',
          :optional    => false,
          :maxlength   => 150

    input :type,
          :prompt      => "Type",
          :description => "Resource Type",
          :type        => :string,
          :validation  => '^.+$',
          :optional    => false,
          :maxlength   => 50

    output :result,
           :description => "The result from the Puppet resource",
           :display_as  => "Result",
           :default     => ""

    output :changed,
           :description => "Was a change applied based on the resource",
           :display_as  => "Changed",
           :default     => nil

    summarize do
        aggregate boolean_summary(:changed, {:true => "Changed", :false => "No Change"})
    end
end

action "disable", :description => "Disable the Puppet agent" do
    input :message,
          :prompt      => "Message",
          :description => "Supply a reason for disabling the Puppet agent",
          :type        => :string,
          :validation  => :shellsafe,
          :optional    => true,
          :maxlength   => 120

    output :status,
           :description => "Status",
           :display_as  => "Status",
           :default     => ""

    output :enabled,
           :description => "Is the agent currently locked",
           :display_as  => "Enabled"

    summarize do
        aggregate boolean_summary(:enabled, {:true => "enabled", :false => "disabled"})
    end
end

action "enable", :description => "Enable the Puppet agent" do
    output :status,
           :description => "Status",
           :display_as  => "Status",
           :default     => ""

    output :enabled,
           :description => "Is the agent currently locked",
           :display_as  => "Enabled"

    summarize do
        aggregate boolean_summary(:enabled, {:true => "enabled", :false => "disabled"})
    end
end

action "last_run_summary", :description => "Get the summary of the last Puppet run" do
    display :always

    input  :logs,
           :description => "Whether or not to parse the logs from last_run_report.yaml",
           :prompt      => "Parse log from last_run_report.yaml",
           :optional    => true,
           :type        => :boolean,
           :default     => false

    output :out_of_sync_resources,
           :description => "Resources that were not in desired state",
           :display_as  => "Out of Sync Resources",
           :default     => -1

    output :failed_resources,
           :description => "Resources that failed to apply",
           :display_as  => "Failed Resources",
           :default     => -1

    output :corrected_resources,
           :description => "Resources that were correctively changed",
           :display_as  => "Corrected Resources",
           :default     => -1

    output :changed_resources,
           :description => "Resources that were changed",
           :display_as  => "Changed Resources",
           :default     => -1

    output :total_resources,
           :description => "Total resources managed on a node",
           :display_as  => "Total Resources",
           :default     => 0

    output :config_retrieval_time,
           :description => "Time taken to retrieve the catalog from the master",
           :display_as  => "Config Retrieval Time",
           :default     => -1

    output :total_time,
           :description => "Total time taken to retrieve and process the catalog",
           :display_as  => "Total Time",
           :default     => 0

    output :logs,
           :description => "Log lines from the last Puppet run",
           :display_as  => "Last Run Logs",
           :default     => {}

    output :lastrun,
           :description => "When the Agent last applied a catalog in local time",
           :display_as  => "Last Run",
           :default     => 0

    output :since_lastrun,
           :description => "How long ago did the Agent last apply a catalog in local time",
           :display_as  => "Since Last Run",
           :default     => "Unknown"

    output :config_version,
           :description => "Puppet config version for the previously applied catalog",
           :display_as  => "Config Version",
           :default     => nil

    output :type_distribution,
           :description => "Resource counts per type managed by Puppet",
           :display_as  => "Type Distribution",
           :default     => {}

    output :summary,
           :description => "Summary data as provided by Puppet",
           :display_as  => "Summary",
           :default     => {}

    summarize do
        aggregate average(:config_retrieval_time, :format => "Average: %0.2f")
        aggregate average(:total_time, :format => "Average: %0.2f")
        aggregate average(:total_resources, :format => "Average: %d")
    end
end

action "status", :description => "Get the current status of the Puppet agent" do
    display :always

    output :applying,
           :description => "Is a catalog being applied",
           :display_as  => "Applying",
           :default     => false

    output :idling,
           :description => "Is the Puppet agent daemon running but not doing any work",
           :display_as  => "Idling",
           :default     => false

    output :enabled,
           :description => "Is the agent currently locked",
           :display_as  => "Enabled"

    output :daemon_present,
           :description => "Is the Puppet agent daemon running on this system",
           :display_as  => "Daemon Running",
           :default     => false

    output :lastrun,
           :description => "When the Agent last applied a catalog in local time",
           :display_as  => "Last Run",
           :default     => 0

    output :since_lastrun,
           :description => "How long ago did the Agent last apply a catalog in local time",
           :display_as  => "Since Last Run",
           :default     => "Unknown"

    output :status,
           :description => "Current status of the Puppet agent",
           :display_as  => "Status",
           :default     => "unknown"

    output :disable_message,
           :description => "Message supplied when agent was disabled",
           :display_as  => "Lock Message",
           :default     => ""


    summarize do
        aggregate boolean_summary(:enabled, {:true => "enabled", :false => "disabled"})
        aggregate boolean_summary(:daemon_present, {:true => "running", :false => "stopped"})
        aggregate summary(:applying)
        aggregate summary(:status)
        aggregate summary(:idling)
    end
end

action "runonce", :description => "Invoke a single Puppet run" do
    input :force,
          :prompt      => "Force",
          :description => "Will force a run immediately else subject to default splay time",
          :type        => :boolean,
          :optional    => true

    input :server,
          :prompt      => "Puppet Master",
          :description => "Address and port of the Puppet Master in server:port format",
          :type        => :string,
          :validation  => :puppet_server_address,
          :optional    => true,
          :maxlength   => 50

    input :tags,
          :prompt      => "Tags",
          :description => "Restrict the Puppet run to a comma list of tags",
          :type        => :string,
          :validation  => :puppet_tags,
          :optional    => true,
          :maxlength   => 120

    input :noop,
          :prompt      => "No-op",
          :description => "Do a Puppet dry run",
          :type        => :boolean,
          :optional    => true

    input :splay,
          :prompt      => "Splay",
          :description => "Sleep for a period before initiating the run",
          :type        => :boolean,
          :optional    => true

    input :splaylimit,
          :prompt      => "Splay Limit",
          :description => "Maximum amount of time to sleep before run",
          :type        => :number,
          :optional    => true

    input :environment,
          :prompt      => "Environment",
          :description => "Which Puppet environment to run",
          :type        => :string,
          :validation  => :puppet_variable,
          :optional    => true,
          :maxlength   => 50

    input :use_cached_catalog,
          :prompt      => "Use Cached Catalog",
          :description => "Determine if to use the cached catalog or not",
          :type        => :boolean,
          :optional    => true

    output :summary,
           :description => "Summary of command run",
           :display_as  => "Summary",
           :default     => ""

    output :initiated_at,
           :description => "Timestamp of when the runonce command was issues",
           :display_as  => "Initiated at",
           :default     => 0
end
