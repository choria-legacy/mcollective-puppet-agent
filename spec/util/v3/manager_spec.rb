#!/usr/bin/env rspec

require 'spec_helper'

Puppet.features(:microsoft_windows? => false)

['puppet_agent_mgr', 'puppet_agent_mgr/v2/manager', 'puppet_agent_mgr/v3/manager'].each do |f|
  require File.expand_path('%s/../../../util/%s' % [File.dirname(__FILE__), f])
end

module MCollective::Util
  module PuppetAgentMgr::V3
    describe Manager do
      before :each do
        @manager = PuppetAgentMgr::V3::Manager.new(nil, true)
      end

      describe "#enable!" do
        it "should raise when it's already enabled" do
          @manager.expects(:enabled?).returns(true)
          expect { @manager.enable! }.to raise_error("Already enabled")
        end

        it "should attempt to remove the lock file" do
          File.expects(:unlink).with("agent_disabled_lockfile")
          @manager.expects(:enabled?).returns(false)
          @manager.enable!
        end
      end

      describe "#disable!" do
        it "should raise when it's already disabld" do
          @manager.expects(:enabled?).returns(false)
          expect { @manager.disable! }.to raise_error("Already disabled")
        end

        it "should set an empty message if none is supplied" do
          @manager.expects(:enabled?).returns(true)
          time = Time.now
          msg = "Disabled using the Ruby API at %s" % time.strftime("%c")

          Time.stubs(:now).returns(time)
          jsonfile = StringIO
          jsonfile.expects(:print).with(JSON.dump(:disabled_message => msg))

          @manager.expects(:atomic_file).with("agent_disabled_lockfile").yields(jsonfile)

          @manager.disable!.should == msg
        end

        it "should lock with the supplied message if supplied" do
          @manager.expects(:enabled?).returns(true)
          time = Time.now
          msg = "test"

          Time.stubs(:now).returns(time)
          jsonfile = StringIO
          jsonfile.expects(:print).with(JSON.dump(:disabled_message => msg))

          @manager.expects(:atomic_file).with("agent_disabled_lockfile").yields(jsonfile)

          @manager.disable!(msg).should == msg

        end
      end

      describe "#managed_resources" do
        it "should return an empty list when the resources file does not exist" do
          Puppet.expects(:[]).with(:resourcefile).returns("resources")
          File.expects(:exist?).with("resources").returns(false)

          @manager.managed_resources.should == []
        end

        it "should read the file and return the contents if it exist" do
          Puppet.expects(:[]).with(:resourcefile).returns("resources").twice
          File.expects(:exist?).with("resources").returns(true)
          File.expects(:readlines).with("resources").returns(["file[x]\n", "file[y]\n"])

          @manager.managed_resources.should == ["file[x]", "file[y]"]
        end
      end

      describe "#lastrun" do
        it "should retrieve the previous run time from the summary" do
          summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}
          summary["time"] = {"last_run" => Time.now.to_i}

          @manager.expects(:load_summary).returns(summary)
          @manager.lastrun.should == summary["time"]["last_run"]
        end

        it "should default to 0 when no time could be found" do
          summary = {"changes" => {}, "time" => {}, "resources" => {}, "version" => {}, "events" => {}}

          @manager.expects(:load_summary).returns(summary)
          @manager.lastrun.should == 0
        end
      end

      describe "#lock_message" do
        it "should return '' when it is not disabled" do
          @manager.expects(:disabled?).returns(false)
          @manager.lock_message.should == ""
        end

        it "should return the right message when it is disabled" do
          @manager.expects(:disabled?).returns(true)
          lock_data = JSON.dump(:disabled_message => "rspec")
          File.expects(:read).with("agent_disabled_lockfile").returns(lock_data)
          @manager.lock_message.should == "rspec"
        end
      end

      describe "#disabled?" do
        it "should return false if the lock file does not exist" do
          File.expects(:exist?).with("agent_disabled_lockfile").returns(false)
          @manager.disabled?.should == false
        end

        it "should return true if it exists" do
          File.expects(:exist?).with("agent_disabled_lockfile").returns(true)
          @manager.disabled?.should == true
        end
      end
    end
  end
end
