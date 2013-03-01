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

      it "should ensure compound filters are empty" do
        client = mock
        client.stubs(:filter).returns("compound" => [{}])
        expect { Puppetrunner.new(client, {:concurrency => 1}) }.to raise_error("The compound filter should be empty")
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
      it "should run each host as quick as it can and only discover when it has to" do
        @runner.stubs(:wait_for_applying_nodes).returns(3).once
        @runner.expects(:runhost).with("one")
        @runner.expects(:runhost).with("two")
        @runner.expects(:runhost).with("three")
        @runner.stubs(:sleep)
        @runner.runhosts(["one", "two", "three"])
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
        @runner.client.expects(:compound_filter).with("puppet().enabled=true")
        @runner.client.expects(:discover).returns(["rspec"])
        @runner.find_enabled_nodes.should == ["rspec"]
      end
    end

    describe "#wait_for_applying_nodes" do
      it "should discover applying nodes till below concurrency is found" do
        @runner.client.expects(:compound_filter).with("puppet().applying=true")
        @runner.client.expects(:reset).times(4)
        @runner.client.expects(:discover).times(4).returns(["one", "two"], ["one", "two"], ["one", "two"], [])

        @runner.expects(:sleep).times(3)
        @runner.stubs(:log)

        @runner.wait_for_applying_nodes.should == 2
      end
    end

    describe "#runhost" do
      it "should run the node with direct addressing" do
        @runner.stubs(:log)
        @runner.client.expects(:discover).with(:nodes => "rspec")
        @runner.client.expects(:runonce).with(:force => true).returns([{:data => {:summary => "rspec"}}])
        @runner.client.expects(:reset)
        @runner.runhost("rspec")
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
  end
end
