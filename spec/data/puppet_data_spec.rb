#!/usr/bin/env rspec

require 'spec_helper'
require '%s/../../util/puppet_agent_mgr.rb' % File.dirname(__FILE__)

describe "puppet data" do
  before do
    @data_file = File.expand_path(File.join(File.dirname(__FILE__),
                                            "../../data/puppet_data.rb"))
    @data = MCollective::Test::DataTest.new("puppet_data",
                                            :data_file => @data_file).plugin
  end

  describe "#query_data" do
    it "should work" do
      MCollective::Config.instance.expects(:pluginconf).returns(
        {"puppet.config" => "rspec"})

      manager = mock
      MCollective::Util::PuppetAgentMgr.expects(:manager).with("rspec").returns(
        manager)

      manager.expects(:status).returns(
         {:status=>"stopped",
          :since_lastrun=>274639,
          :lastrun=>1350376830,
          :applying=>false,
          :message=>"Currently stopped; last completed run 3 days " \
                    "4 hours 17 minutes 19 seconds ago",
          :enabled=>true,
          :daemon_present=>false,
          :disable_message=>"",
          :idling => true})
      
      @data.lookup(nil).should have_data_items(
         {:applying => false,
          :enabled => true,
          :idling => true,
          :daemon_present => false,
          :lastrun => 1350376830,
          :since_lastrun => 274639,
          :status => "stopped",
          :disable_message => ""})
    end
  end
end
