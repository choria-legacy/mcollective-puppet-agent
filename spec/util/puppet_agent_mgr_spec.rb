#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../..', 'util', 'puppet_agent_mgr.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../..', 'util', 'puppet_agent_mgr',
                                   'mgr_v2.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../..', 'util', 'puppet_agent_mgr',
                                   'mgr_v3.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),
                                   '../..', 'util', 'puppet_agent_mgr',
                                   'mgr_windows.rb'))


module MCollective::Util
  describe PuppetAgentMgr do
    before :each do
      MCollective::Config.instance.stubs(:pluginconf).returns({})
    end

    describe "parent manager" do

      describe "#manager" do

        it "should support puppet 2.x.x managers" do
          Puppet.expects(:version).returns("2.7.12")
          PuppetAgentMgr::MgrV2.expects(:new)
          PuppetAgentMgr.manager(nil, nil, nil, true)
        end

        it "should support puppet 3.x.x managers" do
          Puppet.expects(:version).returns("3.0.0")
          PuppetAgentMgr::MgrV3.expects(:new)
          PuppetAgentMgr.manager(nil, "puppet", nil, true)
        end

        it "should use the 3 manager for puppet 4" do
          Puppet.expects(:version).returns("4.0.0")
          PuppetAgentMgr::MgrV3.expects(:new)
          PuppetAgentMgr.manager(nil, "puppet", nil, true)
        end

        it "should pass the supplied config file to the manager" do
          Puppet.expects(:version).returns("3.0.0")
          PuppetAgentMgr::MgrV3.expects(:new).with(
            "rspec", "puppet", true)
          PuppetAgentMgr.manager("rspec", "puppet", nil, true)
        end

        it "should pass the supplied service name to the manager" do
          Puppet.expects(:version).returns("3.0.0")
          PuppetAgentMgr::MgrV3.expects(:new).with(
            "rspec", "pe-puppet", true)
          PuppetAgentMgr.manager("rspec", "pe-puppet", nil, true)
        end

        it "should fail with a friendly error for unsupported puppet versions" do
          Puppet.expects(:version).returns("0.22")
          expect {
            PuppetAgentMgr.manager(nil, nil, nil, true)
          }.to raise_error("Cannot manage Puppet version 0")
        end

        it "should fail with a friendly error " \
           "when it cannot determine the Puppet version" do
          Puppet.expects(:version).returns("x")
          expect {
            PuppetAgentMgr.manager(nil, nil, nil, true)
          }.to raise_error("Cannot determine the Puppet major version")
        end
      end

    end # end of the parent manager section



    describe "puppet V2 manager" do

      before :each do
        MCollective::Util.stubs(:windows?).returns(false)
        Puppet.stubs(:version).returns('2.7.12')
        @manager = PuppetAgentMgr::manager(nil, nil, nil, true)
      end

      describe "#enable!" do
        it "should raise when it's already enabled" do
          @manager.expects(:enabled?).returns(true)
          expect { @manager.enable! }.to raise_error("Already enabled")
        end

        it "should attempt to remove the lock file" do
          File.expects(:unlink).with(Puppet[:puppetdlockfile])
          @manager.expects(:enabled?).returns(false)
          @manager.enable!
        end
      end

      describe "#disable!" do
        it "should raise when it's already disabld" do
          @manager.expects(:enabled?).returns(false)
          expect { @manager.disable! }.to raise_error("Already disabled")
        end

        it "should create the lockfile with the correct path" do
          @manager.expects(:enabled?).returns(true)

          File.expects(:open).with("puppetdlockfile", "w")

          @manager.disable!
        end
      end

      describe "#managed_resources" do
        it "should return an empty list when the resources file does not exist" do
          File.expects(:exist?).with("resourcefile").returns(false)

          @manager.managed_resources.should == []
        end

        it "should read the file and return the contents if it exist" do
          File.expects(:exist?).with("resourcefile").returns(true)
          File.expects(:readlines).with("resourcefile").returns(
            ["file[x]\n", "file[y]\n"])

          @manager.managed_resources.should == ["file[x]", "file[y]"]
        end
      end

      describe "#lastrun" do
        it "should retrieve the previous run time from the summary" do
          summary = {"changes" => {}, "time" => {}, "resources" => {},
                     "version" => {}, "events" => {}}
          summary["time"] = {"last_run" => Time.now.to_i}

          @manager.expects(:load_summary).returns(summary)
          @manager.lastrun.should == summary["time"]["last_run"]
        end

        it "should default to 0 when no time could be found" do
          summary = {"changes" => {}, "time" => {}, "resources" => {},
                     "version" => {}, "events" => {}}

          @manager.expects(:load_summary).returns(summary)
          @manager.lastrun.should == 0
        end
      end

      describe "#lock_message" do
        it "should always return an empty string" do
          @manager.lock_message.should == ""
        end
      end

      describe "#disabled?" do
        it "should return false if the lock file does not exist" do
          File.expects(:exist?).with("puppetdlockfile").returns(false)
          File::Stat.expects(:new).never
          @manager.disabled?.should == false
        end

        it "should return false if the lock file is not empty" do
          stat = OpenStruct.new(:zero? => false)
          File.expects(:exist?).with("puppetdlockfile").returns(true)
          File::Stat.expects(:new).with("puppetdlockfile").returns(stat)
          @manager.disabled?.should == false
        end

        it "should return true if it is zero size" do
          stat = OpenStruct.new(:zero? => true)
          File.expects(:exist?).with("puppetdlockfile").returns(true)
          File::Stat.expects(:new).with("puppetdlockfile").returns(stat)
          @manager.disabled?.should == true
        end
      end

      # NB: the following are the same specs as V3 (below - old Common module)

      describe "#stopped?" do
        it "should be the opposite of applying?" do
          @manager.expects(:applying?).returns(false)
          @manager.stopped?.should == true
        end
      end

      describe "#idling?" do
        it "should be true when the daemon is present and " \
           "it is not applying a catalog" do
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:applying?).returns(false)
          @manager.idling?.should == true
        end

        it "should be false when the daemon is not present" do
          @manager.expects(:daemon_present?).returns(false)
          @manager.expects(:applying?).never
          @manager.idling?.should == false
        end

        it "should be false when the agent is applying a catalog" do
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:applying?).returns(true)
          @manager.idling?.should == false
        end
      end

      describe "#enabled?" do
        it "should be the opposite of disabled?" do
          @manager.expects(:disabled?).returns(false)
          @manager.enabled?.should == true
        end
      end

      describe "#since_lastrun" do
        it "should correctly calculate the time based on lastrun" do
          lastrun = Time.now - 10
          time = Time.now

          Time.expects(:now).returns(time)
          @manager.expects(:lastrun).returns(lastrun)

          @manager.since_lastrun.should == 10
        end

      end

      describe "#managing_resource?" do
        it "should correctly report the managed state" do
          @manager.expects(:managed_resources).returns(["file[x]"]).times(3)

          @manager.managing_resource?("File[x]").should == true
          @manager.managing_resource?("File[y]").should == false
          @manager.managing_resource?("File[X]").should == false
        end

        it "should fail on resource names it cannot parse" do
          expect {
            @manager.managing_resource?("File")
          }.to raise_error("Invalid resource name File")
        end
      end

      describe "#load_summary" do
        it "should return a default structure when no file is found" do
          Puppet.expects(:[]).with(:lastrunfile).returns("lastrunfile")

          @manager.load_summary.should \
            == {"changes"   => {},
                "time"      => {},
                "resources" => {"failed" => 0,
                                "changed" => 0,
                                "corrective_change" => 0,
                                "total" => 0,
                                "restarted" => 0,
                                "out_of_sync" => 0},
                "version"   => {},
                "events"    => {}}
        end

        it "should return merged results if the file is found" do
          yamlfile = File.expand_path(File.join(File.dirname(__FILE__),
                                                "..", "fixtures",
                                                "last_run_summary.yaml"))
          Puppet.expects(:[]).with(:lastrunfile).returns(yamlfile).twice

          @manager.load_summary.should \
            == {"changes"   => {},
                "time"      => {},
                "resources" => {},
                "version"   => {},
                "events"    => {}}.merge(YAML.load_file(yamlfile))
        end
      end

      describe "#managed_resource_type_distribution" do
        it "should correctly count the resource types" do
          Puppet.stubs(:[]).with(:resourcefile).returns("resourcefile")
          File.stubs(:exist?).with("resourcefile").returns(true)
          File.expects(:readlines).with("resourcefile").returns(
            ["file[x]", "exec[foo[bar]]", "rspec::test[x]"])
          @manager.managed_resource_type_distribution.should \
            == {"File" => 1, "Exec" => 1, "Rspec::Test" => 1}
        end
      end

      describe "#last_run_logs" do
        it "should return a default structure when no file is found" do
          Puppet.expects(:[]).with(:lastrunreport).returns("lastrunreport")

          expect(@manager.last_run_logs).to eq([])
        end

        it "should return log results if the file is found" do
          yamlfile = File.expand_path(File.join(File.dirname(__FILE__),
                                                "..", "fixtures",
                                                "last_run_report.yaml"))
          Puppet.expects(:[]).with(:lastrunreport).returns(yamlfile).times(2..3)

          expect(@manager.last_run_logs).to eq([
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"notice", "source"=>"Puppet", "msg"=>"Notice level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"err", "source"=>"Puppet", "msg"=>"Err level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"warning", "source"=>"Puppet", "msg"=>"Warning level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"debug", "source"=>"Puppet", "msg"=>"Debug level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"crit", "source"=>"Puppet", "msg"=>"Crit level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"alert", "source"=>"Puppet", "msg"=>"Alert level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"info", "source"=>"Puppet", "msg"=>"Info level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"emerg", "source"=>"Puppet", "msg"=>"Emerg level message"}
          ])
        end
      end

      describe "#managed_resources_count" do
        it "should report the right size" do
          @manager.expects(:managed_resources).returns(["file[x]"])

          @manager.managed_resources_count.should == 1
        end
      end

      describe "#runonce!" do

        it "should only accept valid option keys" do
          expect {
            @manager.runonce! :rspec => true
          }.to raise_error("Unknown option rspec specified")
        end

        it "should fail when a daemon is idling " \
           "and tags, environment or noop is specified" do

          @manager.stubs(:idling?).returns(true)
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)

          expect {
            @manager.runonce!(:noop => true)
          }.to raise_error("Cannot specify any custom puppet options " \
                           "when the daemon is running")
          expect {
            @manager.runonce!(:environment => "production")
          }.to raise_error("Cannot specify any custom puppet options " \
                           "when the daemon is running")
        end

        it "should raise when it is already applying" do
          @manager.expects(:applying?).returns(true)
          expect {
            @manager.runonce!
          }.to raise_error(/Puppet is currently applying/)
        end

        it "should raise when it is disabled" do
          @manager.stubs(:applying?).returns(false)
          @manager.expects(:disabled?).returns(true)
          expect { @manager.runonce! }.to raise_error(/Puppet is disabled/)
        end

        it "should do a foreground run when requested" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.stubs(:daemon_present?).returns(false)

          @manager.expects(:run_in_foreground)
          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:foreground_run => true)
        end

        it "should do a foreground run when configured with signal_daemon=false" do
          MCollective::Config.instance.stubs(:pluginconf).returns({
            'puppet.signal_daemon' => 'false',
          })
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.stubs(:daemon_present?).returns(false)

          @manager.expects(:run_in_foreground)
          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!
        end

        it "should support returning foreground run arguments only" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.stubs(:daemon_present?).returns(false)

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:foreground_run => true,
                            :options_only => true).should \
            == [:foreground_run, ["--onetime", "--no-daemonize", "--color=false",
                                  "--show_diff", "--verbose"]]
        end

        it "should support sending a signal to the daemon when it is idling" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(true).times(4)

          @manager.expects(:run_in_foreground).never
          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon)

          @manager.runonce!
          @manager.runonce!(:options_only => true).should \
            == [:signal_running_daemon, []]
        end

        it "should do a foreground run when signalling a daemon is not allowed" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(true).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never
          @manager.expects(:run_in_foreground)

          @manager.runonce!(:signal_daemon => false)
        end

        it "should do a foreground run if asked to run" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(false).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never
          @manager.expects(:run_in_foreground)

          @manager.runonce!
        end

        it "should support returning foreground run arguments only" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(false).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:options_only => true).should \
            ==  [:run_in_foreground, ["--onetime", "--no-daemonize",
                                      "--color=false", "--show_diff",
                                      "--verbose"]]
        end
      end

      describe "#valid_name?" do
        it "should test single character variable names" do
          @manager.valid_name?("1").should == false
          @manager.valid_name?("a").should == true
          @manager.valid_name?("_").should == false
        end

        it "should test multi character variable names" do
          @manager.valid_name?("1a").should == true
          @manager.valid_name?("ab").should == true
          @manager.valid_name?("a_b").should == true
          @manager.valid_name?("a-b").should == false
        end
      end

      describe "#create_common_puppet_cli" do

        it "should test the host and port" do
          expect {
            @manager.create_common_puppet_cli(nil, nil, nil, "foo bar")
          }.to raise_error(/The hostname/)
          expect {
            @manager.create_common_puppet_cli(nil, nil, nil, "foo:bar")
          }.to raise_error(/The port/)

          servers_and_parameters = \
            [["foo:10", ["--server foo", "--masterport 10"]],
             ["foo", ["--server foo"]],
             ["1.1.1.1", ["--server 1.1.1.1"]],
             ["1.1.1.1:10", ["--server 1.1.1.1", "--masterport 10"]],
             ["::1", ["--server ::1"]],
             ["[::1]:10", ["--server ::1", "--masterport 10"]]]

          servers_and_parameters.map do |server, parameters|
            @manager.create_common_puppet_cli(
              nil, nil, nil, server).should == parameters
          end
        end

        it "should support noop" do
          @manager.create_common_puppet_cli(nil).should == []
          @manager.create_common_puppet_cli(true).should == ["--noop"]
          @manager.create_common_puppet_cli(false).should == ["--no-noop"]
        end

        it "should support tags" do
          @manager.create_common_puppet_cli(
            nil, ["one"]).should == ["--tags one"]
          @manager.create_common_puppet_cli(
            nil, ["one", "two"]).should == ["--tags one,two"]
        end

        it "should support environment" do
          @manager.create_common_puppet_cli(
            nil, nil, "production").should == ["--environment production"]
        end

        it "should sanity check environment" do
          expect {
            @manager.create_common_puppet_cli(nil, nil, "prod uction")
          }.to raise_error("Invalid environment 'prod uction' specified")
        end

        it "should sanity check tags" do
          expect {
            @manager.create_common_puppet_cli(nil, ["one", "tw o"])
          }.to raise_error("Invalid tag 'tw o' specified")
          expect {
            @manager.create_common_puppet_cli(nil, ["one::two", "tw o"])
          }.to raise_error("Invalid tag 'tw o' specified")
        end

        it "should support splay" do
          @manager.create_common_puppet_cli(nil, nil, nil, nil, true).should \
            == ["--splay"]
          @manager.create_common_puppet_cli(nil, nil, nil, nil, false).should \
            == ["--no-splay"]
        end

        it "should support splaylimit" do
          @manager.create_common_puppet_cli(
            nil, nil, nil, nil, true, 10).should == ["--splay", "--splaylimit 10"]
        end

        it "should support ignoreschedules" do
          @manager.create_common_puppet_cli(
            nil, nil, nil, nil, nil, nil, true).should == ["--ignoreschedules"]
        end
      end

      describe "#{}seconds_to_human" do
        it "should correctly turn seconds into human times" do
          @manager.seconds_to_human(1).should == "01 seconds"
          @manager.seconds_to_human(61).should == "1 minutes 01 seconds"
          @manager.seconds_to_human((61*61)).should \
            == "1 hours 2 minutes 01 seconds"
          @manager.seconds_to_human((24*61*61)).should \
            == "1 day 0 hours 48 minutes 24 seconds"
          @manager.seconds_to_human((48*61*61)).should \
            == "2 days 1 hours 36 minutes 48 seconds"
        end
      end

      describe "#status" do
        it "should correctly retrieve the status" do
          time = Time.now
          lastrun = (time - 10).to_i
          Time.stubs(:now).returns(time)

          @manager.expects(:applying?).returns(true)
          @manager.expects(:enabled?).returns(true)
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:lastrun).returns(lastrun)
          @manager.expects(:lock_message).returns("locked")
          @manager.expects(:idling?).returns(true)

          @manager.status.should \
            == {:applying => true,
                :daemon_present => true,
                :disable_message => "locked",
                :enabled => true,
                :idling => true,
                :lastrun => lastrun,
                :since_lastrun => 10,
                :message => "Currently applying a catalog; last " \
                            "completed run 10 seconds ago",
                :status => "applying a catalog"}
        end
      end

      describe "#atomic_file" do
        it "should create a temp file in the right directory and rename it" do
          file = StringIO.new
          file.expects(:path).returns("/tmp/x.xxx")
          file.expects(:puts).with("hello world")
          File.expects(:rename).with("/tmp/x.xxx", "/tmp/x")
          Tempfile.expects(:new).with("x", "/tmp").returns(file)

          @manager.atomic_file("/tmp/x") {|f| f.puts "hello world"}
        end
      end

    end # end of the puppet V2 manager section



    describe "puppet V3 manager" do

      before :each do
        MCollective::Util.stubs(:windows?).returns(false)
        Puppet.stubs(:version).returns('3.0.0')
        @manager = PuppetAgentMgr::manager(nil, 'puppet', nil, true)
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

          @manager.expects(:atomic_file).with("agent_disabled_lockfile").yields(
            jsonfile)

          @manager.disable!.should == msg
        end

        it "should lock with the supplied message if supplied" do
          @manager.expects(:enabled?).returns(true)
          time = Time.now
          msg = "test"

          Time.stubs(:now).returns(time)
          jsonfile = StringIO
          jsonfile.expects(:print).with(JSON.dump(:disabled_message => msg))

          @manager.expects(:atomic_file).with("agent_disabled_lockfile").yields(
            jsonfile)

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
          File.expects(:readlines).with("resources").returns(["file[x]\n",
                                                              "file[y]\n"])

          @manager.managed_resources.should == ["file[x]", "file[y]"]
        end
      end

      describe "#lastrun" do
        it "should retrieve the previous run time from the summary" do
          summary = {"changes" => {}, "time" => {}, "resources" => {},
                     "version" => {}, "events" => {}}
          summary["time"] = {"last_run" => Time.now.to_i}

          @manager.expects(:load_summary).returns(summary)
          @manager.lastrun.should == summary["time"]["last_run"]
        end

        it "should default to 0 when no time could be found" do
          summary = {"changes" => {}, "time" => {}, "resources" => {},
                     "version" => {}, "events" => {}}

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

      # NB: the following are the same specs as V2 (old Common module)

      describe "#stopped?" do
        it "should be the opposite of applying?" do
          @manager.expects(:applying?).returns(false)
          @manager.stopped?.should == true
        end
      end

      describe "#idling?" do
        it "should be true when the daemon is present and " \
           "it is not applying a catalog" do
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:applying?).returns(false)
          @manager.idling?.should == true
        end

        it "should be false when the daemon is not present" do
          @manager.expects(:daemon_present?).returns(false)
          @manager.expects(:applying?).never
          @manager.idling?.should == false
        end

        it "should be false when the agent is applying a catalog" do
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:applying?).returns(true)
          @manager.idling?.should == false
        end
      end

      describe "#enabled?" do
        it "should be the opposite of disabled?" do
          @manager.expects(:disabled?).returns(false)
          @manager.enabled?.should == true
        end
      end

      describe "#since_lastrun" do
        it "should correctly calculate the time based on lastrun" do
          lastrun = Time.now - 10
          time = Time.now

          Time.expects(:now).returns(time)
          @manager.expects(:lastrun).returns(lastrun)

          @manager.since_lastrun.should == 10
        end
      end

      describe "#managing_resource?" do
        it "should correctly report the managed state" do
          @manager.expects(:managed_resources).returns(["file[x]"]).times(3)

          @manager.managing_resource?("File[x]").should == true
          @manager.managing_resource?("File[y]").should == false
          @manager.managing_resource?("File[X]").should == false
        end

        it "should fail on resource names it cannot parse" do
          expect {
            @manager.managing_resource?("File")
          }.to raise_error("Invalid resource name File")
        end
      end

      describe "#load_summary" do
        it "should return a default structure when no file is found" do
          Puppet.expects(:[]).with(:lastrunfile).returns("lastrunfile")

          @manager.load_summary.should \
            == {"changes" => {},
                "time" => {},
                "resources" => {"failed" => 0,
                                "corrective_change" => 0,
                                "changed" => 0,
                                "total" => 0,
                                "restarted" => 0,
                                "out_of_sync" => 0},
                "version" => {},
                "events" => {}}
        end

        it "should return merged results if the file is found" do
          yamlfile = File.expand_path(File.join(File.dirname(__FILE__),
                                                "..", "fixtures",
                                                "last_run_summary.yaml"))
          Puppet.expects(:[]).with(:lastrunfile).returns(yamlfile).twice

          @manager.load_summary.should \
            == {"changes" => {},
                "time" => {},
                "resources" => {},
                "version" => {},
                "events" => {}}.merge(YAML.load_file(yamlfile))
        end
      end

      describe "#managed_resource_type_distribution" do
        it "should correctly count the resource types" do
          Puppet.stubs(:[]).with(:resourcefile).returns("resourcefile")
          File.stubs(:exist?).with("resourcefile").returns(true)
          File.expects(:readlines).with("resourcefile").returns(
            ["file[x]", "exec[foo[bar]]", "rspec::test[x]"])
          @manager.managed_resource_type_distribution.should \
            == {"File" => 1, "Exec" => 1, "Rspec::Test" => 1}
        end
      end

      describe "#last_run_logs" do
        it "should return a default structure when no file is found" do
          Puppet.expects(:[]).with(:lastrunreport).returns("lastrunreport")

          expect(@manager.last_run_logs).to eq([])
        end

        it "should return log results if the file is found" do
          yamlfile = File.expand_path(File.join(File.dirname(__FILE__),
                                                "..", "fixtures",
                                                "last_run_report.yaml"))
          Puppet.expects(:[]).with(:lastrunreport).returns(yamlfile).times(2..3)

          expect(@manager.last_run_logs).to eq([
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"notice", "source"=>"Puppet", "msg"=>"Notice level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"err", "source"=>"Puppet", "msg"=>"Err level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"warning", "source"=>"Puppet", "msg"=>"Warning level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"debug", "source"=>"Puppet", "msg"=>"Debug level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"crit", "source"=>"Puppet", "msg"=>"Crit level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"alert", "source"=>"Puppet", "msg"=>"Alert level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"info", "source"=>"Puppet", "msg"=>"Info level message"},
            {"time_utc"=>1378216841, "time"=>1378216841, "level"=>"emerg", "source"=>"Puppet", "msg"=>"Emerg level message"}
          ])
        end
      end

      describe "#managed_resources_count" do
        it "should report the right size" do
          @manager.expects(:managed_resources).returns(["file[x]"])

          @manager.managed_resources_count.should == 1
        end
      end

      describe "#valid_name?" do
        it "should test single character variable names" do
          @manager.valid_name?("1").should == false
          @manager.valid_name?("a").should == true
          @manager.valid_name?("_").should == false
        end

        it "should test multi character variable names" do
          @manager.valid_name?("1a").should == true
          @manager.valid_name?("ab").should == true
          @manager.valid_name?("a_b").should == true
          @manager.valid_name?("a-b").should == false
        end
      end

      describe "#create_common_puppet_cli" do

        it "should test the host and port" do
          expect {
            @manager.create_common_puppet_cli(nil, nil, nil, "foo bar")
          }.to raise_error(/The hostname/)
          expect {
            @manager.create_common_puppet_cli(nil, nil, nil, "foo:bar")
          }.to raise_error(/The port/)

          servers_and_parameters = \
            [["foo:10", ["--server foo", "--masterport 10"]],
             ["foo", ["--server foo"]],
             ["1.1.1.1", ["--server 1.1.1.1"]],
             ["1.1.1.1:10", ["--server 1.1.1.1", "--masterport 10"]],
             ["::1", ["--server ::1"]],
             ["[::1]:10", ["--server ::1", "--masterport 10"]]]

          servers_and_parameters.map do |server, parameters|
            @manager.create_common_puppet_cli(
              nil, nil, nil, server).should == parameters
          end
        end

        it "should support noop" do
          @manager.create_common_puppet_cli(nil).should == []
          @manager.create_common_puppet_cli(true).should == ["--noop"]
          @manager.create_common_puppet_cli(false).should == ["--no-noop"]
        end

        it "should support tags" do
          @manager.create_common_puppet_cli(
            nil, ["one"]).should == ["--tags one"]
          @manager.create_common_puppet_cli(
            nil, ["one", "two"]).should == ["--tags one,two"]
        end

        it "should support environment" do
          @manager.create_common_puppet_cli(
            nil, nil, "production").should == ["--environment production"]
        end

        it "should sanity check environment" do
          expect {
            @manager.create_common_puppet_cli(nil, nil, "prod uction")
          }.to raise_error("Invalid environment 'prod uction' specified")
        end

        it "should sanity check tags" do
          expect {
            @manager.create_common_puppet_cli(nil, ["one", "tw o"])
          }.to raise_error("Invalid tag 'tw o' specified")
          expect {
            @manager.create_common_puppet_cli(nil, ["one::two", "tw o"])
          }.to raise_error("Invalid tag 'tw o' specified")
        end

        it "should support splay" do
          @manager.create_common_puppet_cli(nil, nil, nil, nil, true).should \
            == ["--splay"]
          @manager.create_common_puppet_cli(nil, nil, nil, nil, false).should \
            == ["--no-splay"]
        end

        it "should support splaylimit" do
          @manager.create_common_puppet_cli(
            nil, nil, nil, nil, true, 10).should == ["--splay", "--splaylimit 10"]
        end

        it "should support ignoreschedules" do
          @manager.create_common_puppet_cli(
            nil, nil, nil, nil, nil, nil, true).should == ["--ignoreschedules"]
        end
      end

      describe "#runonce!" do

        it "should only accept valid option keys" do
          expect {
            @manager.runonce! :rspec => true
          }.to raise_error("Unknown option rspec specified")
        end

        it "should fail when a daemon is idling " \
           "and tags, environment or noop is specified" do

          @manager.stubs(:idling?).returns(true)
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)

          expect {
            @manager.runonce!(:noop => true)
          }.to raise_error("Cannot specify any custom puppet options " \
                           "when the daemon is running")
          expect {
            @manager.runonce!(:environment => "production")
          }.to raise_error("Cannot specify any custom puppet options " \
                           "when the daemon is running")
        end

        it "should raise when it is already applying" do
          @manager.expects(:applying?).returns(true)
          expect {
            @manager.runonce!
          }.to raise_error(/Puppet is currently applying/)
        end

        it "should raise when it is disabled" do
          @manager.stubs(:applying?).returns(false)
          @manager.expects(:disabled?).returns(true)
          expect { @manager.runonce! }.to raise_error(/Puppet is disabled/)
        end

        it "should do a foreground run when requested" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.stubs(:daemon_present?).returns(false)

          @manager.expects(:run_in_foreground)
          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:foreground_run => true)
        end

        it "should support returning foreground run arguments only" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.stubs(:daemon_present?).returns(false)

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:foreground_run => true,
                            :options_only => true).should \
            == [:foreground_run, ["--onetime", "--no-daemonize", "--color=false",
                                  "--show_diff", "--verbose"]]
        end

        it "should support sending a signal to the daemon when it is idling" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(true).times(4)

          @manager.expects(:run_in_foreground).never
          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon)

          @manager.runonce!
          @manager.runonce!(:options_only => true).should \
            == [:signal_running_daemon, []]
        end

        it "should do a foreground run when signalling a daemon is not allowed" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(true).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never
          @manager.expects(:run_in_foreground)

          @manager.runonce!(:signal_daemon => false)
        end

        it "should do a foreground run if asked to run" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(false).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never
          @manager.expects(:run_in_foreground)

          @manager.runonce!
        end

        it "should support returning foreground run arguments only" do
          @manager.stubs(:applying?).returns(false)
          @manager.stubs(:disabled?).returns(false)
          @manager.expects(:idling?).returns(false).twice

          @manager.expects(:run_in_background).never
          @manager.expects(:signal_running_daemon).never

          @manager.runonce!(:options_only => true).should \
            == [:run_in_foreground, ["--onetime", "--no-daemonize",
                                     "--color=false", "--show_diff", "--verbose"]]
        end
      end

      describe "#{}seconds_to_human" do
        it "should correctly turn seconds into human times" do
          @manager.seconds_to_human(1).should == "01 seconds"
          @manager.seconds_to_human(61).should == "1 minutes 01 seconds"
          @manager.seconds_to_human((61*61)).should \
            == "1 hours 2 minutes 01 seconds"
          @manager.seconds_to_human((24*61*61)).should \
            == "1 day 0 hours 48 minutes 24 seconds"
          @manager.seconds_to_human((48*61*61)).should \
            == "2 days 1 hours 36 minutes 48 seconds"
        end
      end

      describe "#status" do
        it "should correctly retrieve the status" do
          time = Time.now
          lastrun = (time - 10).to_i
          Time.stubs(:now).returns(time)

          @manager.expects(:applying?).returns(true)
          @manager.expects(:enabled?).returns(true)
          @manager.expects(:daemon_present?).returns(true)
          @manager.expects(:lastrun).returns(lastrun)
          @manager.expects(:lock_message).returns("locked")
          @manager.expects(:idling?).returns(true)

          @manager.status.should \
            == {:applying => true,
                :daemon_present => true,
                :disable_message => "locked",
                :enabled => true,
                :idling => true,
                :lastrun => lastrun,
                :since_lastrun => 10,
                :message => "Currently applying a catalog; last " \
                            "completed run 10 seconds ago",
                :status => "applying a catalog"}
        end
      end

      describe "#atomic_file" do
        it "should create a temp file in the right directory and rename it" do
          file = StringIO.new
          file.expects(:path).returns("/tmp/x.xxx")
          file.expects(:puts).with("hello world")
          File.expects(:rename).with("/tmp/x.xxx", "/tmp/x")
          Tempfile.expects(:new).with("x", "/tmp").returns(file)

          @manager.atomic_file("/tmp/x") {|f| f.puts "hello world"}
        end
      end

    end # end of the puppet V3 manager section

  end
end
