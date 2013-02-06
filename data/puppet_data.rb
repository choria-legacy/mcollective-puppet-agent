module MCollective
  module Data
    class Puppet_data<Base
      activate_when do
        require 'mcollective/util/puppet_agent_mgr'
        true
      end

      query do |resource|
        configfile = Config.instance.pluginconf.fetch("puppet.config", nil)

        puppet_agent = Util::PuppetAgentMgr.manager(configfile)
        status = puppet_agent.status

        [:applying, :enabled, :daemon_present, :lastrun, :since_lastrun, :status, :disable_message, :idling].each do |item|
          result[item] = status[item]
        end
      end
    end
  end
end


