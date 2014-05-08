#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_server_address_validator.rb"))

module MCollective
  module Validator
    describe Puppet_server_addressValidator do

      it "should expect strings" do
        Validator.expects(:typecheck).with(1, :string).raises("not a string")
        expect {
          Puppet_server_addressValidator.validate(1)
        }.to raise_error("not a string")
      end

      it "should expect shellsafe strings" do
        Validator.expects(:typecheck).with(1, :string)
        Validator.expects(:validate).with(1, :shellsafe).raises("not shellsafe")
        expect {
          Puppet_server_addressValidator.validate(1)
        }.to raise_error("not shellsafe")
      end

      def validate_servers (good_servers, bad_servers)
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)
        good_servers.each do |server|
          Puppet_server_addressValidator.validate(server)
        end
        bad_servers.each do |server|
          expect {
            Puppet_server_addressValidator.validate(server)
          }.to raise_error("The hostname '%s' is not a valid hostname" % server)
        end
      end

      it "should correctly validate just a host name" do
        # NB: an int is a valid IPv6 addr for the ipaddr lib on ruby 1.8.7!
        #     We don't allow that.
        validate_servers(
          ["box", "box.com", "a.box.com", "a-nother.box.com", "a"],
          ["foo bar", "1", "1000", "300000", "a_box",
           "a_nother.box.com", "1.2"])
      end

      it "should correctly validate just an IPv4 address" do
        validate_servers(
          ["1.1.1.1", "255.255.255.255"],
          ["300.1.1.1", "200.200"])
      end

      it "should correctly validate just an IPv6 address" do
        validate_servers(
          ["fe80::7a31:c1ff:fed6:92a2", "::FFFF:129.144.52.38",
           "2001:0db8:0000:0000:0000:ff00:0042:8329", "::1"],
          ["fe80::7a31:c1ff:fed6:92a2:e0e0e0",
           "gggg::7a31:c1ff:fed6:92a2"])
      end

      def validate_ports (good_servers, bad_servers_ports)
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)
        good_servers.each do |server|
          Puppet_server_addressValidator.validate(server)
        end
        bad_servers_ports.each do |server, port|
          expect {
            Puppet_server_addressValidator.validate(server)
          }.to raise_error("The port '%s' is not a valid puppet master port" % port)
        end
      end

      it "should correctly validate hostname ports as well as host" do
        validate_ports(
          ["a:123"],
          [["a:a", "a"]])
      end

      it "should correctly validate IPv4 ports as well as host" do
        validate_ports(
          ["1.1.1.1:123"],
          [["1.1.1.1:a", "a"]])
      end

      it "should correctly validate IPv6 ports as well as host" do
        validate_ports(
          ["[::1]:123", "[2001:0db8:0000:0000:0000:ff00:0042:8329]:9999"],
          [["[::1]:a", "a"],
           ["[2001:0db8:0000:0000:0000:ff00:0042:8329]:b", "b"]])
      end
    end
  end
end
