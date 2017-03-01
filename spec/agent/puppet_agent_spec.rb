#!/usr/bin/env rspec

require 'spec_helper'
require '%s/../../util/puppet_agent_mgr.rb' % File.dirname(__FILE__)

describe "puppet agent" do

  describe "#startup_hook" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "should support custom config files" do
      MCollective::Config.instance.stubs(:pluginconf).returns(
        {"puppet.config" => "rspec"})
      MCollective::Util::PuppetAgentMgr.expects(:manager).with("rspec", "puppet")

      @agent.startup_hook
    end

    it "should set the service name based on the config" do
      MCollective::Config.instance.stubs(:pluginconf).returns(
        {"puppet.windows_service" => "not-puppet"})
      MCollective::Util::PuppetAgentMgr.expects(:manager).with(nil, "not-puppet")

      @agent.startup_hook
    end
  end

  describe "#default_agent_command" do
    before do
      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "on Windows it should use puppet.bat" do
      MCollective::Util.stubs(:windows?).returns(true)
      expect(@agent.default_agent_command).to eq("puppet.bat agent")
    end

    it "on non-Windows it should use puppet" do
      MCollective::Util.stubs(:windows?).returns(false)
      expect(@agent.default_agent_command).to eq("puppet agent")
    end
  end

  describe "#resource" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    before do
      @type = mock; @resource = mock; @catalog = mock; @report = mock
      @resource_status = mock; @resource_statuses = mock

      Puppet::Type.stubs(:type).returns(@type)
      Puppet::Util::Log.stubs(:newdestination)
      Puppet::Resource::Catalog.stubs(:new).returns(@catalog)
      Puppet::Transaction::Report.stubs(:new).returns(@report)

      @manager.stubs(:managing_resource?).returns(false)
      @type.stubs(:new).returns(@resource)
      @catalog.stubs(:add_resource)
      @catalog.stubs(:apply)
      @report.stubs(:logs).returns([])
      @report.stubs(:resource_statuses).returns(@resource_statuses)
      @resource_statuses.stubs(:[]).returns(@resource_status)
      @resource_status.stubs(:failed).returns(false)
      @resource_status.stubs(:changed).returns(true)
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_type_whitelist" => "notify,host",
				 "puppet.resource_name_whitelist.notify" => "ssh,hello world",
         "puppet.resource_name_blacklist.host" => "hadoop"})
    end

    it "should not allow both a white and a blacklist" do
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_type_whitelist" => "notify,host",
         "puppet.resource_type_blacklist" => "x"})

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_aborted_error
      result[:statusmsg].should == "You cannot specify both " \
        "puppet.resource_type_whitelist and puppet.resource_type_blacklist " \
        "in the config file"
    end

    it "should not allow both a resource name white and a blacklist for resource type" do
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_name_whitelist.notify" => "ssh,hello world",
         "puppet.resource_name_blacklist.notify" => "x"})

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_aborted_error
      result[:statusmsg].should == "You cannot specify both " \
        "puppet.resource_name_whitelist.notify and puppet.resource_name_blacklist.notify " \
        "in the config file"
    end

    it "should only allow types on the whitelist when set" do
      ["notify", "host"].each do |t|
        result = @agent.call(:resource, :type => t, :name => "hello world")
        result.should be_successful
        result[:data][:result].should == "no output produced"
      end

      result = @agent.call(:resource, :type => "exec", :name => "hello world")
      result.should be_aborted_error
    end

    it "should only allow names on the whitelist when set" do
      ["notify", "host"].each do |t|
        result = @agent.call(:resource, :type => t, :name => "hello world")
        result.should be_successful
        result[:data][:result].should == "no output produced"
      end

      result = @agent.call(:resource, :type => "notify", :name => "ntp")
      result.should be_aborted_error
    end

    it "should not allow types on the blacklist when set" do
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_type_blacklist" => "notify,host"})

      ["notify", "host"].each do |t|
        result = @agent.call(:resource, :type => t, :name => "hello world")
        result.should be_aborted_error
      end

      result = @agent.call(:resource, :type => "exec", :name => "hello world")
      result.should be_successful
      result[:data][:result].should == "no output produced"
    end

    it "should not allow names on the blacklist when set" do
      ["host"].each do |t|
        result = @agent.call(:resource, :type => t, :name => "hadoop")
        result.should be_aborted_error
      end

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_successful
      result[:data][:result].should == "no output produced"
    end

    it "should reply with the logs joined if there are any" do
      @report.stubs(:logs).returns(["one", "two"])

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_successful
      result[:data][:result].should == "one\ntwo"
    end

    it "should fail the request if the resource failed to apply" do
      @resource_status.stubs(:failed).returns(true)
      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_aborted_error
      result[:statusmsg].should == "Failed to apply Notify[hello world]: " \
                                   "no output produced"
    end

    it "should refuse to manage managed resources when configured so" do
      @manager.stubs(:managing_resource?).returns(true)
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_type_whitelist" => "notify,host",
         "puppet.resource_allow_managed_resources" => "false"})

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_aborted_error
      result[:statusmsg].should == "Puppet is managing the resource " \
        "'Notify[hello world]', refusing to create conflicting states"
    end

    it "should allow managing puppet managed resources when configured so" do
      @manager.stubs(:managing_resource?).returns(true)
      @agent.config.stubs(:pluginconf).returns(
        {"puppet.resource_type_whitelist" => "notify,host",
         "puppet.resource_allow_managed_resources" => "true"})

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_successful
    end

    it "should correctly report the resource change state on success" do
      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_successful
      result.should have_data_items({:changed => true})
    end

    it "should correctly report the resource change state on failure" do
      @resource_status.stubs(:changed).returns(false)

      result = @agent.call(:resource, :type => "notify", :name => "hello world")
      result.should be_successful
      result.should have_data_items({:changed => false})
    end
  end

  describe "#disable" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "should support using a default message" do
      t = Time.now
      Time.expects(:now).returns(t)

      msg = "Disabled via MCollective by unknown at %s" % t.strftime("%F %R")

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
      @manager.expects(:status).returns({
        :status => "stopped",
        :since_lastrun => 274639,
        :lastrun => 1350376830,
        :applying => false,
        :message => "Currently stopped; last completed run 3 days 4 hours " \
                    "17 minutes 19 seconds ago",
        :enabled => true,
        :daemon_present => false,
        :disable_message => "",
        :idling => true,
      })
      result = @agent.call(:disable)
      result.should be_aborted_error
      result[:statusmsg].should == "Could not disable Puppet: rspec"
    end
  end

  describe "#enable" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "should enable the agent" do
      @manager.expects(:status).returns({:enabled => true})
      @manager.expects(:enable!)
      result = @agent.call(:enable)
      result.should be_successful
      result[:data][:status].should == "Succesfully enabled the Puppet agent"
    end

    it "should fail with a friendly error message" do
      @manager.expects(:enable!).raises("rspec")
      @manager.expects(:status).returns({
        :status => "stopped",
        :since_lastrun => 274639,
        :lastrun => 1350376830,
        :applying => false,
        :message => "Currently stopped; last completed run 3 days 4 hours 17 " \
                    "minutes 19 seconds ago",
        :enabled => true,
        :daemon_present => false,
        :disable_message => "",
        :idling => true,
      })
      result = @agent.call(:enable)
      result.should be_aborted_error
      result[:statusmsg].should == "Could not enable Puppet: rspec"
    end
  end

  describe "#last_run_summary" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "should return the correct data" do
      t = Time.now
      Time.expects(:now).returns(t)

      summary = {"changes" =>{ "total"=>1},
                 "events" => {"success"=>1,
                              "failure"=>0,
                              "total"=>1},
                 "version" => {"config"=>1350376829,
                               "puppet"=>"3.0.0"},
                 "resources" => {"failed_to_restart" => 0,
                                 "changed" => 1,
                                 "failed" => 0,
                                 "restarted" => 0,
                                 "scheduled" => 0,
                                 "out_of_sync" => 1,
                                 "skipped" => 6,
                                 "total" => 8},
                 "time" => {"filebucket" => 0.000144,
                            "last_run" => 1350376830,
                            "config_retrieval" => 0.148587,
                            "notify" => 0.001058,
                            "total" => 0.149789}}
      logs = { :some_logs => 1 }

      @manager.expects(:load_summary).returns(summary)
      @manager.stubs(:last_run_logs).returns(logs)
      @manager.expects(:managed_resource_type_distribution).returns(
        {"File" => 1, "Exec" => 2})

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
      result[:data][:logs].should == {}
      result[:data][:type_distribution].should == {"File" => 1, "Exec" => 2}
    end

    context 'logs' do
      before :each do
        @manager.stubs(:load_summary).returns({})
      end

      context 'default (false)' do
        it 'should not call on last_run_logs' do
          @manager.expects(:last_run_logs).never
          @agent.call(:last_run_summary)
        end
      end

      context 'true' do
        it 'should call on last_run_logs' do
          @manager.expects(:last_run_logs).once
          @agent.call(:last_run_summary, :logs => true)
        end
      end
    end
  end

  describe "#status" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file).plugin
    end

    it "should return the correct status" do
      status = {:status => "stopped",
                :since_lastrun => 97529,
                :lastrun => 1350376830,
                :applying => false,
                :message => "Currently stopped; last completed run 1 day " \
                            "3 hours 5 minutes 29 seconds ago",
                :enabled => true,
                :daemon_present => false,
                :disable_message => ""}

      @manager.expects(:status).returns(status)
      result = @agent.call(:status)
      result.should be_successful
      result[:data].should == status
    end
  end

  describe "runonce" do
    before :each do
      # instantiate a new manager for each spec
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('2.7.12')
      @manager = MCollective::Util::PuppetAgentMgr.manager(nil, nil, nil, true)

      @agent_file = File.join(File.dirname(__FILE__), "../../agent/puppet.rb")
      @agent = MCollective::Test::LocalAgentTest.new("puppet",
                                             :agent_file => @agent_file,
                                             :config => {
                                               "plugin.puppet.command" => "puppet agent"
                                             }).plugin
    end

    before do
      @manager.stubs(:status).returns({})
      @manager.stubs(:signal_running_daemon)
      @manager.stubs(:disabled?).returns(false)
    end

    it "should fail if the agent is currently disabled" do
      @manager.expects(:disabled?).returns(true)
      @manager.expects(:lock_message).returns("locked by rspec")
      result = @agent.call(:runonce)
      result.should have_data_items(:summary => "Puppet is disabled: " \
                                                "'locked by rspec'")
    end

    it "should set splay option to false when force is given" do
      @manager.expects(:status).returns(
        {:enabled => false})
      @manager.expects(:runonce!).with({
        :options_only => true,
        :splay => false,
      }).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :force => true)
      result.should be_successful
    end

    it "should support ignoreschedules" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :ignoreschedules => true,
         :splay => true,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :ignoreschedules => true)
      result.should be_successful
    end

    it "should support no-noop" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :noop => false,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :noop => false)
      result.should be_successful
    end

    it "should support noop" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :noop => true,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :noop => true)
      result.should be_successful
    end

    it "should support no-use_cached_catalog" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :use_cached_catalog => false,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :use_cached_catalog => false)
      result.should be_successful
    end

    it "should support use_cached_catalog" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :use_cached_catalog => true,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :use_cached_catalog => true)
      result.should be_successful
    end

    it "should support setting the environment" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
          :splay => true,
          :environment => "rspec",
          :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :environment => "rspec")
      result.should be_successful
    end

    it "should not by default support setting the server to use" do
      result = @agent.call(:runonce, :server => "rspec:123")
      result.should be_aborted_error
      result[:statusmsg].should == "Passing 'server' option is not allowed " \
                                   "in module configuration"
    end

    it "should support setting the server to use if explicitly allowed in configuration" do
      MCollective::PluginManager.clear
      agent = MCollective::Test::LocalAgentTest.new(
                "puppet",
                :agent_file => @agent_file,
                :config => {"plugin.puppet.allow_server_override" => true}).plugin
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :server => "rspec:123",
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = agent.call(:runonce, :server => "rspec:123")
      result.should be_successful
    end

    it "should support setting the tags" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :tags => ["one", "two"],
         :splay => true,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :tags => "one,two")
      result.should be_successful
    end

    it "should support setting splay" do
      MCollective::PluginManager.clear
      agent = MCollective::Test::LocalAgentTest.new(
                "puppet",
                :agent_file => @agent_file,
                :config => {"plugin.puppet.splay" => false}).plugin

      @manager.expects(:runonce!).with(
        {:options_only=>true,
         :splay => true,
         :splaylimit => 30}).returns([:signal_running_daemon, []])
      result = agent.call(:runonce, :splay => true)
      result.should be_successful
    end

    it "should support setting no-splay" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => false}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :splay => false)
      result.should be_successful
    end

    it "should support setting splaylimit" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :splaylimit => 60}).returns([:signal_running_daemon, []])
      result = @agent.call(:runonce, :splaylimit => 60)
      result.should be_successful
    end

    it "should support running puppet with the given arguments" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :splaylimit => 30}).returns([:run_in_foreground, ["--rspec"]])
      @agent.expects(:run).with("puppet agent --rspec",
                                :stdout => :summary,
                                :stderr => :summary,
                                :chomp => true).returns(0)

      result = @agent.call(:runonce)
      result.should be_successful
    end

    it "should fail with a friendly message if puppet returns non zero" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :splaylimit => 30}).returns([:run_in_foreground, ["--rspec"]])
      @agent.expects(:run).with("puppet agent --rspec",
                                :stdout => :summary,
                                :stderr => :summary,
                                :chomp => true).returns(1)

      result = @agent.call(:runonce)
      result.should be_aborted_error
      result[:statusmsg].should == "Puppet command 'puppet agent --rspec' " \
                                   "had exit code 1, expected 0"
    end

    it "should fail for unsupported run methods" do
      @manager.expects(:runonce!).with(
        {:options_only => true,
         :splay => true,
         :splaylimit => 30}).returns([:rspec, []])

      result = @agent.call(:runonce)
      result.should be_aborted_error
      result[:statusmsg].should == "Do not know how to do puppet runs " \
                                   "using method rspec"
    end
  end
end
