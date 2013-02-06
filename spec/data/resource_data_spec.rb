#!/usr/bin/env rspec

require 'spec_helper'
require '%s/../../util/puppet_agent_mgr.rb' % File.dirname(__FILE__)

describe "puppet data" do
  before do
    @data_file = File.join([File.dirname(__FILE__), "../../data/resource_data.rb"])
    @data = MCollective::Test::DataTest.new("resource_data", :data_file => @data_file).plugin
  end


  describe "#query_data" do
    it "should work" do
      MCollective::Config.instance.expects(:pluginconf).returns({"puppet.config" => "rspec"})
      manager = mock
      MCollective::Util::PuppetAgentMgr.expects(:manager).with("rspec").returns(manager)


      manager.expects(:load_summary).returns({"version"=>{"puppet"=>"3.0.0", "config"=>1350376829},
                                              "changes"=>{"total"=>1},
                                              "resources"=> {"out_of_sync"=>1,
                                                "failed"=>0,
                                                "total"=>8,
                                                "changed"=>1,
                                                "restarted"=>0,
                                                "skipped"=>6,
                                                "failed_to_restart"=>0,
                                                "scheduled"=>0},
                                                "time"=> {"total"=>0.149789,
                                                  "last_run"=>1350376830,
                                                  "filebucket"=>0.000144,
                                                  "notify"=>0.001058,
                                                  "config_retrieval"=>0.148587},
                                                  "events"=>{"total"=>1, "failure"=>0, "success"=>1}})

      manager.expects(:managing_resource?).with("File[rspec]").returns(true)

      time = Time.now; Time.expects(:now).returns(time)
      @data.lookup("File[rspec]").should have_data_items({:managed => true,
                                                          :out_of_sync_resources => 1,
                                                          :failed_resources => 0,
                                                          :changed_resources => 1,
                                                          :total_resources => 8,
                                                          :total_time => 0.149789,
                                                          :config_retrieval_time => 0.148587,
                                                          :lastrun => 1350376830,
                                                          :since_lastrun => Integer(time - 1350376830),
                                                          :config_version => 1350376829})
    end
  end
end
