#!/usr/bin/env rspec

require 'spec_helper'
require '%s/../../util/puppet_agent_mgr.rb' % File.dirname(__FILE__)

describe "puppet agent" do
  before do
    @manager = mock
    MCollective::Util::PuppetAgentMgr.stubs(:manager).returns(@manager)

    @agent_file = File.join([File.dirname(__FILE__), "../../agent/puppet.rb"])
    @agent = MCollective::Test::LocalAgentTest.new("puppet", :agent_file => @agent_file).plugin
  end

  describe "#disable" do
    it "should support using a default message" do
      t = Time.now
      Time.expects(:now).returns(t)

      msg = "Disabled via MCollective by unknown at %s local time" % t

      @manager.expects(:status).returns({:enabled => false})
      @manager.expects(:disable!).with(msg).returns(msg)
      result = @agent.call(:disable)
      result.should be_successful
      result[:data][:status].should == "Succesfully locked the Puppet agent: %s" % msg
    end

    it "should support using a custom message" do
      t = Time.now
      Time.expects(:now).returns(t)

      @manager.expects(:status).returns({:enabled => false})
      @manager.expects(:disable!).with("x").returns("x")
      result = @agent.call(:disable, :message => "x")
      result.should be_successful
      result[:data][:status].should == "Succesfully locked the Puppet agent: x"
    end

    it "should fail with a friendly error message" do
      @manager.expects(:disable!).raises("rspec")
      result = @agent.call(:disable)
      result.should be_aborted_error
      result[:statusmsg].should == "Could not disable Puppet: rspec"
    end
  end

  describe "#enable" do
    it "should enable the agent" do
      @manager.expects(:status).returns({:enabled => true})
      @manager.expects(:enable!)
      result = @agent.call(:enable)
      result.should be_successful
      result[:data][:status].should == "Succesfully enabled the Puppet agent"
    end

    it "should fail with a friendly error message" do
      @manager.expects(:enable!).raises("rspec")
      result = @agent.call(:enable)
      result.should be_aborted_error
      result[:statusmsg].should == "Could not enable Puppet: rspec"
    end
  end

  describe "#last_run_summary" do
    it "should return the correct data" do
      t = Time.now
      Time.expects(:now).returns(t)

      summary = {"changes"=>{"total"=>1}, "events"=>{"success"=>1, "failure"=>0, "total"=>1}, "version"=>{"config"=>1350376829, "puppet"=>"3.0.0"}, "resources"=>{"failed_to_restart"=>0, "changed"=>1, "failed"=>0, "restarted"=>0, "scheduled"=>0, "out_of_sync"=>1, "skipped"=>6, "total"=>8}, "time"=>{"filebucket"=>0.000144, "last_run"=>1350376830, "config_retrieval"=>0.148587, "notify"=>0.001058, "total"=>0.149789}}

      @manager.expects(:load_summary).returns(summary)

      result = @agent.call(:last_run_summary)
      result.should be_successful
      result[:data][:out_of_sync_resources].should == 1
      result[:data][:failed_resources].should == 0
      result[:data][:changed_resources].should == 1
      result[:data][:total_resources].should == 8
      result[:data][:total_time].should == 0.149789
      result[:data][:config_retrieval_time].should == 0.148587
      result[:data][:lastrun].should == 1350376830
      result[:data][:since_lastrun].should == Integer((t - 1350376830))
      result[:data][:config_version].should == 1350376829
      result[:data][:summary].should == summary
    end
  end

  describe "#status" do
    it "should return the correct status" do
      status = {:status=>"stopped", :since_lastrun=>97529, :lastrun=>1350376830, :applying=>false, :message=>"Currently stopped; last completed run 1 day 3 hours 5 minutes 29 seconds ago", :enabled=>true, :daemon_present=>false, :disable_message=>""}

      @manager.expects(:status).returns(status)
      result = @agent.call(:status)
      result.should be_successful
      result[:data].should == status
    end
  end

  describe "runonce" do
    before do
      @manager.stubs(:status).returns({})
      @manager.stubs(:signal_running_daemon)
    end

    it "should not set splay options when force is given" do
      @manager.expects(:runonce!).with({:options_only=>true}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :force => true)
      result.should be_successful
    end

    it "should support no-noop" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :noop=>false, :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :noop => false)
      result.should be_successful
    end

    it "should support noop" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :noop=>true, :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :noop => true)
      result.should be_successful
    end

    it "should support setting the environment" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :environment=>"rspec", :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :environment => "rspec")
      result.should be_successful
    end

    it "should support setting the server to use" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :server=>"rspec:123", :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :server => "rspec:123")
      result.should be_successful
    end

    it "should support setting the tags" do
      @manager.expects(:runonce!).with({:options_only=>true, :tags=>["one", "two"], :splay => true, :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :tags => "one,two")
      result.should be_successful
    end

    it "should support setting splay" do
      MCollective::PluginManager.clear
      agent = MCollective::Test::LocalAgentTest.new("puppet", :agent_file => @agent_file, :config => {"plugin.puppet.splay" => false}).plugin

      @manager.expects(:runonce!).with({:options_only=>true, :splay => true, :splaylimit=>30}).returns([:signal_running_daemon, []])
      result = agent.call(:runonce, :splay => true)
      result.should be_successful
    end

    it "should support setting no-splay" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay => false}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :splay => false)
      result.should be_successful
    end

    it "should support setting splaylimit" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :splaylimit=>60}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :splaylimit => 60)
      result.should be_successful
    end

    it "should support running puppet with the given arguments" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :splaylimit=>30}).returns([:run_in_background, ["--rspec"]])
      @agent.expects(:run).with("puppet agent --rspec", :stdout => :summary, :stderr => :summary, :chomp => true).returns(0)

      result = @agent.call(:runonce)
      result.should be_successful
    end

    it "should fail with a friendly message if puppet returns non zero" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :splaylimit=>30}).returns([:run_in_background, ["--rspec"]])
      @agent.expects(:run).with("puppet agent --rspec", :stdout => :summary, :stderr => :summary, :chomp => true).returns(1)

      result = @agent.call(:runonce)
      result.should be_aborted_error
      result[:statusmsg].should == "Puppet command 'puppet agent --rspec' had exit code 1, expected 0"
    end

    it "should fail for unsupported run methods" do
      @manager.expects(:runonce!).with({:options_only=>true, :splay=>true, :splaylimit=>30}).returns([:rspec, []])

      result = @agent.call(:runonce)
      result.should be_aborted_error
      result[:statusmsg].should == "Do not know how to do puppet runs using method rspec"
    end
  end
end
