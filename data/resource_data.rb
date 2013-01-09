module MCollective
  module Data
    class Resource_data<Base
      activate_when do
        require 'mcollective/util/puppet_agent_mgr'
        true
      end

      query do |resource|
        puppet_agent = Util::PuppetAgentMgr.manager
        summary = puppet_agent.load_summary

        result[:managed] = puppet_agent.managing_resource?(resource) if resource

        result[:out_of_sync_resources] = summary["resources"].fetch("out_of_sync", 0)
        result[:failed_resources] = summary["resources"].fetch("failed", 0)
        result[:changed_resources] = summary["resources"].fetch("changed", 0)
        result[:total_resources] = summary["resources"].fetch("total", 0)
        result[:total_time] = summary["time"].fetch("total", 0)
        result[:config_retrieval_time] = summary["time"].fetch("config_retrieval", 0)
        result[:lastrun] = Integer(summary["time"].fetch("last_run", 0))
        result[:since_lastrun] = Integer(Time.now.to_i - result[:lastrun])
        result[:config_version] = summary["version"].fetch("config", "unknown")
      end
    end
  end
end


