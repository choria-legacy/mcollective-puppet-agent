module MCollective
  module Data
    class Resource_data<Base
      activate_when do
        require 'mcollective/util/puppet_agent_mgr'
        true
      end

      def sanitize_val(result_value, default_value)
        if result_value.nil?
          return default_value
        end
        result_value
      end


      query do |resource|
        configfile = Config.instance.pluginconf.fetch("puppet.config", nil)

        puppet_agent = Util::PuppetAgentMgr.manager(configfile)
        summary = puppet_agent.load_summary

        result[:managed] = puppet_agent.managing_resource?(resource) if resource

        result[:out_of_sync_resources] = sanitize_val(summary["resources"].fetch("out_of_sync", 0), 0)
        result[:failed_resources]      = sanitize_val(summary["resources"].fetch("failed", 0), 0)
        result[:corrected_resources]   = sanitize_val(summary["resources"].fetch("corrective_change", 0), 0)
        result[:changed_resources]     = sanitize_val(summary["resources"].fetch("changed", 0), 0)
        result[:total_resources]       = sanitize_val(summary["resources"].fetch("total", 0), 0)
        result[:total_time]            = sanitize_val(summary["time"].fetch("total", 0), 0)
        result[:config_retrieval_time] = sanitize_val(summary["time"].fetch("config_retrieval", 0), 0)
        result[:lastrun]               = Integer(sanitize_val(summary["time"].fetch("last_run", 0), 0))
        result[:since_lastrun]         = Integer(Time.now.to_i - result[:lastrun])
        result[:config_version]        = sanitize_val(summary["version"].fetch("config", "unknown"), "unknown")
      end
    end
  end
end
