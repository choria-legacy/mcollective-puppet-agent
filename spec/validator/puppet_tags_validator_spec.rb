#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_tags_validator.rb"))

module MCollective
  module Validator
    describe Puppet_tagsValidator do
      it "should expect strings" do
        Validator.expects(:typecheck).with(1, :string).raises("not a string")
        expect { Puppet_tagsValidator.validate(1) }.to raise_error("not a string")
      end

      it "should expect shellsafe strings" do
        Validator.expects(:typecheck).with(1, :string)
        Validator.expects(:validate).with(1, :shellsafe).raises("not shellsafe")

        expect { Puppet_tagsValidator.validate(1) }.to raise_error("not shellsafe")
      end

      it "should validate each supplied part as a valid variable" do
        Validator.stubs(:typecheck)
        Validator.stubs(:validate)
        Validator.expects(:validate).with("one", :puppet_variable)
        Validator.expects(:validate).with("two", :puppet_variable)
        Validator.expects(:validate).with("three", :puppet_variable)

        Puppet_tagsValidator.validate("one,two::three")
      end
    end
  end
end
