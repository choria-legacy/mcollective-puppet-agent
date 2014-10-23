#!/usr/bin/env rspec

require 'spec_helper'

require File.join(File.dirname(__FILE__), File.join('../..', 'util', 'puppetrunner.rb'))

module MCollective::Util
  describe Puppetrunner do
    before do
      filter = MCollective::Util.empty_filter
      client = mock
      client.stubs(:filter).returns(filter)
      client.stubs(:progress=)
      configuration = {:concurrency => 2}
      @runner = Puppetrunner.new(client, configuration)
    end

    describe "#initialize" do
      it "should not allow < 1 concurrency" do
        expect { Puppetrunner.new(mock, {}) }.to raise_error("Concurrency has to be > 0")
      end
    end

    describe "#runall" do
      it "should support reruns" do
        @runner.expects(:runall_forever).with(100)
        @runner.runall(true, 100)
      end

      it "should support single runs" do
        @runner.expects(:runall_once)
        @runner.runall(false, 100)
      end
    end

    describe "#runall_forever" do
      before do
        @runner.stubs(:log)
        @runner.stubs(:sleep)
      end

      it "should loop forever" do
        @runner.expects(:runall_once).times(4)

        @runner.runall_forever(1, 4)
      end

      it "should sleep for the correct period when the run was shorter than minimum" do
        start = Time.now
        stop = start + 10

        Time.expects(:now).twice.returns(start, stop)

        @runner.stubs(:runall_once)
        @runner.expects(:sleep).with(10.0)
        @runner.runall_forever(20, 1)
      end

      it "should not sleep when the run was longer than minimum" do
        start = Time.now
        stop = start + 10

        Time.expects(:now).twice.returns(start, stop)

        @runner.stubs(:runall_once)
        @runner.expects(:sleep).never
        @runner.runall_forever(1, 1)
      end
    end

    describe "#runall_once" do
      it "should find enabled hosts and run them" do
        @runner.stubs(:log)
        @runner.expects(:find_enabled_nodes).returns(["rspec"])
        @runner.expects(:runhosts).with(["rspec"])
        @runner.runall_once
      end
    end

    describe "#runhosts" do
      before :each do
        @runner.stubs(:log)
        @runner.stubs(:sleep)
      end

      it "should run as many nodes as possible until concurrency has been met" do
        @runner.instance_variable_set(:@concurrency, 3)
        @runner.stubs(:find_applying_nodes).returns([])
        @runner.expects(:runhost).with("one")
        @runner.expects(:runhost).with("two")
        @runner.expects(:runhost).with("three")
        @runner.runhosts(["one", "two", "three"])
      end

      it "should put a node in the back of the run queue if it has been put in a running state by some other means" do
        @runner.instance_variable_set(:@concurrency, 1)
        @runner.stubs(:find_applying_nodes).returns(["one"], [])
        @runner.expects(:runhost).with("one").once
        @runner.runhosts(["one"])
      end

      it "should not start another run if max concurrency has been met" do
        @runner.instance_variable_set(:@concurrency, 1)
        @runner.stubs(:find_applying_nodes).returns(["one"], ["one"], [])
        @runner.expects(:runhost).with("one").once
        @runner.expects(:sleep).with(1).twice
        @runner.runhosts(["one"])
      end
    end

    describe "#log" do
      it "should support pluggable loggers" do
        log = StringIO.new

        @runner.logger {|msg| log.puts msg}

        log.expects(:puts).with("rspec was here")
        @runner.log("rspec was here")
      end
    end

    describe "#find_enabled_nodes" do
      it "should discover only enabled nodes" do
        @runner.stubs(:log)
        @runner.stubs(:sleep)
        @runner.client.expects(:compound_filter).with("puppet().enabled=true")
        @runner.client.expects(:discover).returns(["rspec"])
        @runner.find_enabled_nodes.should == ["rspec"]
      end

      it "should discover only enabled nodes with a compound filter" do
        filter = MCollective::Util.empty_filter
        filter["compound"] = [[{"statement"=>"foo"}, {"and"=>"and"}, {"not"=>"not"}, {"statement"=>"bar=baz"}]]
        client = mock
        client.stubs(:filter).returns(filter)
        client.stubs(:progress=)
        configuration = {:concurrency => 2}
        @runner = Puppetrunner.new(client, configuration)
        @runner.stubs(:log)
        @runner.stubs(:sleep)
        @runner.client.expects(:discover).returns(["rspec", "rspec2", "rspec3"])
        @runner.find_enabled_nodes.should == ["rspec", "rspec2", "rspec3"]
        @runner.client.filter["compound"].should == [
                                                     [
                                                      {"fstatement"=>{"name"=>"puppet", "operator"=>"==", "r_compare"=>"true", "params"=>nil, "value"=>"enabled"}},
                                                      {"and"=>"and"},
                                                      {"("=>"("},
                                                      {"statement"=>"foo"},
                                                      {"and"=>"and"},
                                                      {"not"=>"not"},
                                                      {"statement"=>"bar=baz"},
                                                      {")"=>")"}
                                                     ]
                                                    ]
      end
    end

    describe "#runhost" do
      before :each do
        @runner.stubs(:log)
      end

      it "should return 0 when do not get a response from the remote host" do
        @runner.client.expects(:discover).with(:nodes => "rspec")
        @runner.client.expects(:runonce).with(:force => true).returns([])
        @runner.client.expects(:reset)
        @runner.runhost("rspec").should == 0
      end

      it "should return 0 when we encounter a older version of the agent on a remote host" do
        @runner.client.expects(:discover).with(:nodes => "rspec")
        @runner.client.expects(:runonce).with(:force => true).returns([{:data => {:summary => "rspec"}}])
        @runner.client.expects(:reset)
        @runner.runhost("rspec").should == 0
      end

      it "should return the timestamp of when it was envoked" do
        @runner.client.expects(:discover).with(:nodes => "rspec")
        @runner.client.expects(:runonce).with(:force => true).returns([{:data => {:summary => "rspec", :initiated_at => "123"}}])
        @runner.client.expects(:reset)
        @runner.runhost("rspec").should == 123
      end
    end

    describe "#find_applying_nodes" do
      let(:data) do
        [{
          :data => {
            :applying => true,
            :lastrun => 1,
            :initiated_at => 1
          },
          :sender => "host1.example.com"
        },
        {
          :data => {
            :applying => false,
            :lastrun => 2,
            :initiated_at => 1
          },
          :sender => "host2.example.com"
        }]
      end

      it "should return all the nodes that match the 'applying' state" do
        @runner.client.stubs(:status).returns(data)
        @runner.client.stubs(:identity_filter).with("host1.example.com")
        @runner.find_applying_nodes(["host1.example.com"]).should == [{ :name => "host1.example.com",
                                                                        :initiated_at => 1,
                                                                        :no_response => 0,
                                                                        :checks => 0 }]
      end

      it "should return all the nodes that match the 'asked to run but not yet started' state" do
        @runner.client.stubs(:status).returns(data)
        data[0][:data][:applying] = false
        @runner.client.stubs(:identity_filter).with("host1.example.com")
        @runner.find_applying_nodes(["host1.example.com"],
                                    [{ :name => "host1.example.com",
                                       :initiated_at => 2,
                                       :no_response => 0,
                                       :checks => 0 }]).should ==
                                    [{ :name => "host1.example.com",
                                       :initiated_at => 2,
                                       :no_response => 0,
                                       :checks => 1 }]
      end

      it "should return the empty set if nothing is applying" do
        @runner.client.stubs(:status).returns(data)
        data[0][:data][:applying] = false
        @runner.client.stubs(:identity_filter).with("host1.example.com")
        @runner.client.stubs(:identity_filter).with("host2.example.com")
        @runner.find_applying_nodes(["host1.example.com", "host2.example.com"],
                                    [{ :name => "host1.example.com",
                                       :initiated_at => 1,
                                       :no_response => 0,
                                       :checks => 0 },
                                     { :name => "host2.example.com",
                                       :initiated_at => 1,
                                       :no_response => 0,
                                       :checks => 0 }]).should == []

      end

      it "should give a node in the 'asked to run but not yet started' state 5 tries before removing it from the running set" do
        data[1][:data][:initiated_at] = 3
        @runner.client.stubs(:status).returns([data[1]])
        @runner.client.stubs(:identity_filter).with("host2.example.com")
        @runner.expects(:log).with("Host host2.example.com did not move into an applying state. Skipping.").once
        result = @runner.find_applying_nodes(["host2.example.com"],
                                    [{ :name => "host2.example.com",
                                       :initiated_at => 3,
                                       :no_response => 0,
                                       :checks => 0 }])
        result.should == [{:name => "host2.example.com", :initiated_at => 3, :no_response => 0, :checks => 1}]
        result = @runner.find_applying_nodes(["host2.example.com"], result)
        result.should == [{:name => "host2.example.com", :initiated_at => 3, :no_response => 0, :checks => 2}]
        result = @runner.find_applying_nodes(["host2.example.com"], result)
        result.should == [{:name => "host2.example.com", :initiated_at => 3, :no_response => 0, :checks => 3}]
        result = @runner.find_applying_nodes(["host2.example.com"], result)
        result.should == [{:name => "host2.example.com", :initiated_at => 3, :no_response => 0, :checks => 4}]
        result = @runner.find_applying_nodes(["host2.example.com"], result)
        result.should == []
      end

      it 'should log a node not responding' do
        @runner.client.stubs(:status).returns([])
        @runner.client.stubs(:identity_filter).with('host1.example.com')
        @runner.expects(:log).with('Host host1.example.com did not respond to the status action.').once
        statuses = @runner.find_applying_nodes(['host1.example.com'])
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 0, :no_response => 1, :checks => 0}]
      end


      it 'should cope with a node not responding' do
        responses = [{ :sender => 'host1.example.com',
                       :data => {
                         :applying => true,
                         :lastrun => 1,
                         :initiated_at => 1
                       },
                     },
                    ]

        @runner.client.stubs(:status).returns(responses, [], responses)
        @runner.client.stubs(:identity_filter).with('host1.example.com')
        @runner.expects(:log).with('Host host1.example.com did not respond to the status action.').once

        statuses = @runner.find_applying_nodes(['host1.example.com'])
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 1, :no_response => 0, :checks => 0}]

        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == [{:name => "host1.example.com", :initiated_at => 1, :no_response => 1, :checks => 0}]

        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 1, :no_response => 1, :checks => 0}]
      end


      it 'should give up on a non-responsive node after 5 attempts' do
        @runner.client.stubs(:status).returns([])
        @runner.client.stubs(:identity_filter).with('host1.example.com')
        @runner.expects(:log).with('Host host1.example.com did not respond to the status action.').times(5)
        @runner.expects(:log).with('Host host1.example.com failed to respond multiple times. Skipping.').once

        statuses = @runner.find_applying_nodes(['host1.example.com'])
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 0, :no_response => 1, :checks => 0}]
        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 0, :no_response => 2, :checks => 0}]
        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 0, :no_response => 3, :checks => 0}]
        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == [{:name => 'host1.example.com', :initiated_at => 0, :no_response => 4, :checks => 0}]
        statuses = @runner.find_applying_nodes(['host1.example.com'], statuses)
        statuses.should == []
      end
    end

    describe "#runonce_arguments" do
      it "should set the correct arguments" do
        @runner.configuration[:force] = true
        @runner.configuration[:server] = "rspec:123"
        @runner.configuration[:noop] = true
        @runner.configuration[:environment] = "rspec"
        @runner.configuration[:splay] = true
        @runner.configuration[:splaylimit] = 60
        @runner.configuration[:tag] = ["one", "two"]
        @runner.configuration[:ignoreschedules] = true

        @runner.runonce_arguments.should == {:splaylimit=>60, :force=>true, :environment=>"rspec", :noop=>true, :server=>"rspec:123", :tags=>"one,two", :splay=>true, :ignoreschedules=>true}
      end
    end

    describe '#make_status' do
      it 'should default initiated_at' do
        status = @runner.send(:make_status, 'test-host')
        status.should == {
          :name => 'test-host',
          :initiated_at => 0,
          :checks => 0,
          :no_response => 0,
        }
      end

      it 'should allow initiated_at to be specified' do
        status = @runner.send(:make_status, 'test-host', 2551)
        status.should == {
          :name => 'test-host',
          :initiated_at => 2551,
          :checks => 0,
          :no_response => 0,
        }
      end
    end
  end
end
