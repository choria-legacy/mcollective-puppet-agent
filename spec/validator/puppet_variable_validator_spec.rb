#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_variable_validator.rb"))
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_server_address_validator.rb"))

module MCollective
  module Validator
    describe Puppet_variableValidator do
      it "should expect strings" do
        Validator.expects(:typecheck).with(1, :string).raises("not a string")
        expect { Puppet_server_addressValidator.validate(1) }.to raise_error("not a string")
      end

      it "should expect shellsafe strings" do
        Validator.expects(:typecheck).with(1, :string)
        Validator.expects(:validate).with(1, :shellsafe).raises("not shellsafe")

        expect { Puppet_server_addressValidator.validate(1) }.to raise_error("not shellsafe")
      end

      it "should correctly validate single character variables" do
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)

        Puppet_variableValidator.validate("a")
        Puppet_variableValidator.validate("A")
        expect { Puppet_variableValidator.validate("1") }.to raise_error("Invalid variable name '1' specified")
      end

      it "should correctly validate multi character variables" do
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)

        Puppet_variableValidator.validate("a")
        Puppet_variableValidator.validate("A")
        Puppet_variableValidator.validate("1a")
        Puppet_variableValidator.validate("a1")
        expect { Puppet_variableValidator.validate("a-b") }.to raise_error("Invalid variable name 'a-b' specified")
        expect { Puppet_variableValidator.validate("a.b") }.to raise_error("Invalid variable name 'a.b' specified")
        expect { Puppet_variableValidator.validate("a b") }.to raise_error("Invalid variable name 'a b' specified")
      end
    end
  end
end
