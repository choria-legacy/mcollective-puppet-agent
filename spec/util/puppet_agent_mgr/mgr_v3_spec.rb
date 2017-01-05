#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../../..', 'util', 'puppet_agent_mgr.rb'))


module MCollective::Util
  describe PuppetAgentMgr do

    before :each do
      MCollective::Util.stubs(:windows?).returns(false)
      Puppet.stubs(:version).returns('3.0.0')
      @manager = PuppetAgentMgr::manager(nil, 'puppet', nil, true)
    end

    describe "#daemon_present?" do
      it "should return false if the pidfile does not exist" do
        File.expects(:exist?).with("pidfile").returns(false)
        @manager.daemon_present?.should == false
      end

      it "should check the pid if the pidfile exist" do
        File.expects(:exist?).with("pidfile").returns(true)
        File.expects(:read).with("pidfile").returns(1)
        @manager.expects(:has_process_for_pid?).with(1).returns(true)
        @manager.daemon_present?.should == true
      end
    end

    describe "#applying?" do
      it "should return false when the lock file is absent" do
        File.expects(:exist?).with("agent_catalog_run_lockfile").returns(false)
        File::Stat.expects(:new).never
        MCollective::Log.expects(:warn).never
        @manager.applying?.should == false
      end

      it "should check the pid if the lock file is not empty" do
        stat = OpenStruct.new(:size => 1)
        File::Stat.expects(:new).returns(stat)
        File.expects(:exist?).with("agent_catalog_run_lockfile").returns(true)
        File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
        @manager.expects(:has_process_for_pid?).with("1").returns(true)
        @manager.applying?.should == true
      end

      it "should return false if the lockfile is empty" do
        stat = OpenStruct.new(:size => 0)
        File.expects(:exist?).with("agent_catalog_run_lockfile").returns(true)
        File::Stat.expects(:new).returns(stat)
        @manager.applying?.should == false
      end

      it "should return false if the lockfile is stale" do
        stat = OpenStruct.new(:size => 1)
        File::Stat.expects(:new).returns(stat)
        File.expects(:exist?).with("agent_catalog_run_lockfile").returns(true)
        File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
        @manager.expects(:has_process_for_pid?).with("1").returns(false)
        @manager.applying?.should == false
      end

      it "should return false on any error" do
        @manager.expects(:platform_applying?).raises("fail")
        MCollective::Log.expects(:warn)
        @manager.applying?.should == false
      end
    end

    describe "#signal_running_daemon" do
      it "should check if the process is present and send USR1 if present" do
        File.expects(:read).with("pidfile").returns("1")
        @manager.expects(:has_process_for_pid?).with("1").returns(true)
        ::Process.expects(:kill).with("USR1", 1)

        @manager.signal_running_daemon
      end

      it "should fall back to background run if the pid is stale" do
        File.expects(:read).with("pidfile").returns("1")
        @manager.expects(:has_process_for_pid?).with("1").returns(false)
        @manager.expects(:run_in_background)

        @manager.signal_running_daemon
      end
    end

  end
end
