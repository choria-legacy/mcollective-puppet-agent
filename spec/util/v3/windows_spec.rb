require 'spec_helper'

Puppet.features(:microsoft_windows? => true)

['puppet_agent_mgr', 'puppet_agent_mgr/v3/manager'].each do |f|
  require File.expand_path('%s/../../../util/%s' % [File.dirname(__FILE__), f])
end

module MCollective::Util
  module PuppetAgentMgr::V3
    describe "Windows" do
      before :all do
        require File.expand_path('%s/../../../util/puppet_agent_mgr/v3/windows' % [File.dirname(__FILE__)])
      end
      describe "#daemon_present?", :if => MCollective::Util.windows? do
        it "should return false if the service does not exist" do
          Win32::Service.expects(:status).with('pe-puppet').raises(Win32::Service::Error)

          Windows.daemon_present?.should be_false
        end

        it "should return false if the service is stopped" do
          Win32::Service.expects(:status).with('pe-puppet').returns(stub(:current_state => 'stopped'))

          Windows.daemon_present?.should be_false
        end

        ['running', 'continue pending', 'start pending'].each do |state|
          it "should return true if the service is #{state}" do
            Win32::Service.expects(:status).with('pe-puppet').returns(stub(:current_state => state))

            Windows.daemon_present?.should == true
          end
        end
      end

      describe "#applying?" do
        it "should return false when disabled" do
          Windows.expects(:disabled?).returns(true)
          Windows.applying?.should == false
        end

        it "should return false when the lock file is absent" do
          Windows.expects(:disabled?).returns(false)
          File.expects(:read).with("agent_catalog_run_lockfile").raises(Errno::ENOENT)
          MCollective::Log.expects(:warn).never

          Windows.applying?.should == false
        end

        it "should check the pid if the lock file is not empty" do
          Windows.expects(:disabled?).returns(false)
          File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
          Windows.expects(:has_process_for_pid?).with("1").returns(true)

          Windows.applying?.should == true
        end

        it "should return false if the lockfile is empty" do
          Windows.expects(:disabled?).returns(false)
          File.expects(:read).with("agent_catalog_run_lockfile").returns("")

          Windows.applying?.should == false
        end

        it "should return false if the lockfile is stale" do
          Windows.expects(:disabled?).returns(false)
          File.expects(:read).with("agent_catalog_run_lockfile").returns("1")
          Process.stubs(:kill).with(0, 1).raises(Errno::ESRCH)

          Windows.applying?.should == false
        end

        it "should return false on any error" do
          Windows.expects(:disabled?).raises("fail")
          MCollective::Log.expects(:warn)

          Windows.applying?.should == false
        end
      end

      describe "#background_run_allowed?" do
        it "should be true if the daemon is present" do
          Windows.stubs(:daemon_present?).returns true

          Windows.background_run_allowed?.should be_true
        end
        it "should be true if the daemon is not present" do
          Windows.stubs(:daemon_present?).returns false

          Windows.background_run_allowed?.should be_true
        end
      end

      describe "#signal_running_daemon" do
        it "should not be supported" do
          expect { Windows.signal_running_daemon }.to raise_error(/Signalling the puppet daemon is not supported on Windows/)
        end
      end
    end
  end
end
