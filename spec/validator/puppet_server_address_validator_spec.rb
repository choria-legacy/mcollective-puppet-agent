#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_server_address_validator.rb"))

module MCollective
  module Validator
    describe Puppet_server_addressValidator do
      it "should expect strings" do
        Validator.expects(:typecheck).with(1, :string).raises("not a string")
        expect { Puppet_server_addressValidator.validate(1) }.to raise_error("not a string")
      end

      it "should expect shellsafe strings" do
        Validator.expects(:typecheck).with(1, :string)
        Validator.expects(:validate).with(1, :shellsafe).raises("not shellsafe")

        expect { Puppet_server_addressValidator.validate(1) }.to raise_error("not shellsafe")
      end

      it "should correctly validate just a host" do
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)

        ["box", "box.com", "a.box.com", "a-nother.box.com", "a"].each do |box|
          Puppet_server_addressValidator.validate(box)
        end

        ["1", "a_box", "a_nother.box.com", "1.2"].each do |box|
          expect { Puppet_server_addressValidator.validate(box) }.to raise_error("The hostname '%s' is not a valid hostname" % box)
        end
      end

      it "should correctly validate ports as well as host" do
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)

        Puppet_server_addressValidator.validate("a:123")
        expect { Puppet_server_addressValidator.validate("a:a") }.to raise_error("The port 'a' is not a valid puppet master port")
      end
    end
  end
end
