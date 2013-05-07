require '%s/puppet_agent_mgr/common.rb' % File.dirname(__FILE__)

module MCollective
  module Util
    module PuppetAgentMgr
      def self.manager(configfile=nil, service_name='puppet')
        # puppet 2 requires this, 3 probably just ignores it
        $puppet_application_name = :agent

        require 'puppet'
        require 'json'

        if Puppet.version =~ /^(\d+)/
          case $1
            when "2"
              require '%s/puppet_agent_mgr/v2/manager.rb' % File.dirname(__FILE__)
              return V2::Manager.new(configfile)

            when "3"
              require '%s/puppet_agent_mgr/v3/manager.rb' % File.dirname(__FILE__)
              return V3::Manager.new(configfile, service_name)

            else
              raise "Cannot manage Puppet version %s" % $1
          end
        else
          raise "Cannot determine the Puppet major version"
        end
      end
    end
  end
end
