#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../../..', 'util', 'puppet_agent_mgr.rb'))


module MCollective::Util
  describe PuppetAgentMgr do

    before :each do
      MCollective::Util.stubs(:windows?).returns(true)
      Puppet.stubs(:version).returns('3.0.0')
      @manager = PuppetAgentMgr::manager(nil, nil, nil, true)
    end

    describe "#daemon_present?", :if => Puppet.windows? do
      it "should return false if the service does not exist" do
        Win32::Service.expects(:status).with('pe-puppet').raises(
          Win32::Service::Error)
        Windows.daemon_present?.should be_false
      end

      it "should return false if the service is stopped" do
        Win32::Service.expects(:status).with('pe-puppet').returns(
          stub(:current_state => 'stopped'))
        Windows.daemon_present?.should be_false
      end

      ['running', 'continue pending', 'start pending'].each do |state|
        it "should return true if the service is #{state}" do
          Win32::Service.expects(:status).with('pe-puppet').returns(
            stub(:current_state => state))
          Windows.daemon_present?.should == true
        end
      end
    end

    describe "#applying?" do
      it "should return false when disabled" do
        @manager.expects(:disabled?).returns(true)
        @manager.applying?.should == false
      end

      it "should return false when the lock file is absent" do
        @manager.expects(:disabled?).returns(false)
        File.expects(:read).with("agent_catalog_run_lockfile").raises(
          Errno::ENOENT)
        MCollective::Log.expects(:warn).never
        @manager.applying?.should == false
      end

      it "should check the pid if the lock file is not empty" do
        @manager.expects(:disabled?).returns(false)
        File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
        @manager.expects(:has_process_for_pid?).with("1").returns(true)
        @manager.applying?.should == true
      end

      it "should return false if the lockfile is empty" do
        @manager.expects(:disabled?).returns(false)
        File.expects(:read).with("agent_catalog_run_lockfile").returns("")
        @manager.applying?.should == false
      end

      it "should return false if the lockfile is stale" do
        @manager.expects(:disabled?).returns(false)
        File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
        ::Process.stubs(:kill).with(0, 1).raises(Errno::ESRCH)
        @manager.applying?.should == false
      end

      it "should return false on any error" do
        @manager.expects(:disabled?).raises("fail")
        MCollective::Log.expects(:warn)
        @manager.applying?.should == false
      end
    end

    describe "#background_run_allowed?" do
      it "should be true if the daemon is present" do
        @manager.stubs(:daemon_present?).returns true
        @manager.background_run_allowed?.should be_true
      end

      it "should be true if the daemon is not present" do
        @manager.stubs(:daemon_present?).returns false
        @manager.background_run_allowed?.should be_true
      end
    end

    describe "#signal_running_daemon" do
      it "should not be supported" do
        expect {
          @manager.signal_running_daemon
        }.to raise_error(
              /Signalling the puppet daemon is not supported on Windows/)
      end
    end

  end
end
