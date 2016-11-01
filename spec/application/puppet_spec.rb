#!/usr/bin/env rspec

require 'spec_helper'

module MCollective
  class Application
    describe Puppet do
      before do
        application_file = File.join(File.dirname(__FILE__), '../../', 'application', 'puppet.rb')
        @app = MCollective::Test::ApplicationTest.new('puppet', :application_file => application_file).plugin

        client = mock
        client.stubs(:stats).returns(RPC::Stats.new)
        client.stubs(:progress=)
        @app.stubs(:client).returns(client)
        @app.stubs(:printrpc)
        @app.stubs(:printrpcstats)
        @app.stubs(:halt)
      end

      describe "#application_description" do
        it "should have a descrption set" do
          @app.should have_a_description
        end
      end

      describe "#post_option_parser" do
        it "should detect unsupported commands" do
          ARGV << "rspec"
          expect { @app.post_option_parser(@app.configuration) }.to raise_error(/Action must be/)
        end

        it "should get the concurrency for runall" do
          ARGV << "runall"
          ARGV << "1"

          @app.post_option_parser(@app.configuration)
          @app.configuration[:command].should == "runall"
          @app.configuration[:concurrency].should == 1
        end

        it "should get the message for disable" do
          ARGV << "disable"
          ARGV << "rspec test"

          @app.post_option_parser(@app.configuration)
          @app.configuration[:message].should == "rspec test"
        end

        it "should detect when no command is given" do
          ARGV.clear

          @app.expects(:raise_message).with(2)
          @app.post_option_parser(@app.configuration)
        end
      end

      describe "#validate_configuration" do
        it "should not allow the splay option when forcing" do
          @app.configuration[:force] = true
          @app.configuration[:splay] = true

          @app.expects(:raise_message).with(3)
          @app.validate_configuration(@app.configuration)
        end

        it "should not allow the splaylimit option when forcing" do
          @app.configuration[:force] = true
          @app.configuration[:splaylimit] = 60

          @app.expects(:raise_message).with(4)
          @app.validate_configuration(@app.configuration)
        end

        it "should ensure the runall command has a concurrency" do
          @app.configuration[:command] = "runall"

          @app.expects(:raise_message).with(5)
          @app.validate_configuration(@app.configuration)
        end

        it "should make sure the concurrency is > 0" do
          @app.configuration[:command] = "runall"
          @app.configuration[:concurrency] = 0

          @app.expects(:raise_message).with(7)
          @app.validate_configuration(@app.configuration)

          @app.configuration[:concurrency] = 1
          @app.validate_configuration(@app.configuration)
        end
      end

      describe "#shorten_number" do
        it "should shorten numbers correctly" do
          @app.shorten_number("9999999").should == "10.0m"
          @app.shorten_number("8999999").should == "9.0m"
          @app.shorten_number("9000").should == "9.0k"
          @app.shorten_number("9").should == "9.0"
          @app.shorten_number("wat").should == "NaN"
        end
      end

      describe "#calculate_longest_hostname" do
        it "should calculate the correct size" do
          results = [{:sender => "a"}, {:sender => "abcdef"}, {:sender => "ab"}]
          @app.calculate_longest_hostname(results).should == 6
        end
      end

      describe "#display_results_single_field" do
        it "should print succesful results correctly" do
          result = [{:statuscode => 0, :sender => "rspec sender", :data => {:message => "rspec test"}}]
          @app.expects(:puts).with("   rspec sender: rspec test")
          @app.display_results_single_field(result, :message)
        end

        it "should print failed results correctly" do
          result = [{:statuscode => 1, :sender => "rspec sender", :data => {:message => "rspec test"}, :statusmsg => "error"}]
          Util.expects(:colorize).with(:red, "error").returns("error")
          @app.expects(:puts).with("   rspec sender: error")

          @app.display_results_single_field(result, :message)
        end

        it "should not fail for empty results" do
          @app.display_results_single_field([], :message).should == false
        end
      end

      describe "#sparkline_for_field" do
        it "should correctly extract and draw the data" do
          results = []

          (10...22).each do |c|
            results << {:statuscode => 0, :data => {:rspec => c}}
          end

          @app.expects(:spark).with([2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0]).returns("rspec")
          @app.sparkline_for_field(results, :rspec, 11).should == "rspec  min: 10.0   avg: 15.5   max: 21.0  "
        end

        it "should return an empty string with bad data to extract from" do
          results = []
          (10...22).each do |c|
            results << {:statuscode => 1, :data => {:rspec => c}}
          end

          @app.sparkline_for_field(results, :rspec).should == ''
        end

        it "should return an empty string with no data to extract" do
          results = []
          @app.sparkline_for_field(results, :rspec).should == ''
        end

        it "should correctly handle mixed agent versions where some fields might be missing from some results" do
          results = []

          (10...22).each do |c|
            results << {:statuscode => 0, :data => {:rspec => c}}
          end
          results << {:statuscode => 0, :data => {}}

          @app.expects(:spark).with([2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0]).returns("rspec")
          @app.sparkline_for_field(results, :rspec, 11).should == "rspec  min: 10.0   avg: 15.5   max: 21.0  "
        end
      end

      describe "#spark" do
        it "should correctly draw all zeros" do
          @app.spark([0,0,0,0,0], ["0", "1", "2", "3"]).should == "00000"
        end

        it "should draw non zero for small numbers" do
          @app.spark([1,0,0,0,100], ["0", "1", "2", "3"]).should == "10003"
        end
      end

      describe "#runonce_arguments" do
        it "should set the correct arguments" do
          @app.configuration[:force] = true
          @app.configuration[:server] = "rspec:123"
          @app.configuration[:noop] = true
          @app.configuration[:environment] = "rspec"
          @app.configuration[:splay] = true
          @app.configuration[:splaylimit] = 60
          @app.configuration[:tag] = ["one", "two"]
          @app.configuration[:use_cached_catalog] = false
          @app.configuration[:ignoreschedules] = true

          @app.runonce_arguments.should == {:splaylimit=>60, :force=>true, :environment=>"rspec", :noop=>true, :server=>"rspec:123", :tags=>"one,two", :splay=>true, :use_cached_catalog=>false, :ignoreschedules=>true}
        end
      end

      describe "runall_command" do
        it "should use the Puppetrunner to schedule runs" do
          runner = mock
          runner.expects(:logger)
          runner.expects(:runall)

          @app.runall_command(runner)
        end
      end

      describe "#summary_command" do
        it "should gather the summaries and display it" do
          @app.client.expects(:progress=).with(false)
          @app.client.expects(:last_run_summary).returns([])
          @app.expects(:halt)

          [:total_resources, :out_of_sync_resources, :failed_resources, :changed_resources,
           :config_retrieval_time, :total_time, :since_lastrun, :corrected_resources]. each do |field|
              @app.expects(:sparkline_for_field).with([], field)
           end

          @app.summary_command
        end
      end

      describe "#status_command" do
        it "should display the :message result and stats" do
          @app.client.expects(:status).returns("rspec")
          @app.expects(:display_results_single_field).with("rspec", :message)
          @app.expects(:printrpcstats).with(:summarize => true)
          @app.expects(:halt)
          @app.status_command
        end
      end

      describe "#enable_command" do
        it "should enable the daemons and print results" do
          @app.client.expects(:enable)
          @app.expects(:printrpcstats).with(:summarize => true)
          @app.expects(:halt)
          @app.enable_command
        end
      end

      describe "#disable_command" do
        before do
          @app.expects(:printrpcstats).with(:summarize => true)
          @app.expects(:halt)
        end

        it "should support disabling with a message" do
          @app.configuration[:message] = "rspec test"
          @app.client.expects(:disable).with(:message => "rspec test").returns("rspec")
          @app.disable_command
        end

        it "should support disabling without a message" do
          @app.client.expects(:disable).with({}).returns("rspec")
          @app.disable_command
        end
      end

      describe "#runonce_command" do
        it "should run the agent along with any custom arguments" do
          @app.configuration[:force] = true
          @app.configuration[:server] = "rspec:123"
          @app.configuration[:noop] = true
          @app.configuration[:environment] = "rspec"
          @app.configuration[:splay] = true
          @app.configuration[:splaylimit] = 60
          @app.configuration[:tag] = ["one", "two"]
          @app.configuration[:use_cached_catalog] = false
          @app.configuration[:ignoreschedules] = true

          @app.client.expects(:runonce).with(:force => true,
                                             :server => "rspec:123",
                                             :noop => true,
                                             :environment => "rspec",
                                             :splay => true,
                                             :splaylimit => 60,
                                             :use_cached_catalog => false,
                                             :ignoreschedules => true,
                                             :tags => "one,two").returns("result")
          @app.expects(:halt)
          @app.runonce_command
        end
      end

      describe "#count_command" do
        it "should display the totals" do
          @app.client.expects(:status)
          @app.client.stats.expects(:okcount).returns(3)
          @app.client.stats.stubs(:failcount).returns(1)
          Util.expects(:colorize).with(:red, "Failed to retrieve status of 1 node").returns("Failed to retrieve status of 1 node")
          @app.expects(:extract_values_from_aggregates).returns(:enabled => {"enabled" => 3},
                                                                :applying => {true => 1, false => 2},
                                                                :daemon_present => {"running" => 2},
                                                                :idling => {true => 1})


          @app.expects(:puts).with("Total Puppet nodes: 3")
          @app.expects(:puts).with("          Nodes currently enabled: 3")
          @app.expects(:puts).with("         Nodes currently disabled: 0")
          @app.expects(:puts).with("Nodes currently doing puppet runs: 1")
          @app.expects(:puts).with("          Nodes currently stopped: 2")
          @app.expects(:puts).with("       Nodes with daemons started: 2")
          @app.expects(:puts).with("    Nodes without daemons started: 0")
          @app.expects(:puts).with("       Daemons started but idling: 1")
          @app.expects(:puts).with("Failed to retrieve status of 1 node")

          @app.count_command
        end
      end

      describe "#main" do
        it "should call the command if it exist" do
          @app.expects(:count_command)
          @app.configuration[:command] = "count"
          @app.main
        end

        it "should fail gracefully when a command does not exist" do
          @app.expects(:raise_message).with(6, "rspec")
          @app.configuration[:command] = "rspec"
          @app.main
        end
      end
    end
  end
end
