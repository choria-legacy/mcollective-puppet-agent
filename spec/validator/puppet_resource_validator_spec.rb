#!/usr/bin/env rspec

require 'spec_helper'
require File.expand_path(File.join(File.dirname(__FILE__), "../../validator/puppet_resource_validator.rb"))

module MCollective
  module Validator
    describe Puppet_resourceValidator do
      it "should allow valid resource names" do
        Validator.stubs(:typecheck).returns(true)

        ["rspec[abc]", "rspec[ ]", "rspec_rspec[rspec]"].each do |resource|
          Puppet_resourceValidator.validate(resource)
        end

      end

      it "should fail on invalid resource names" do
        Validator.stubs(:typecheck).returns(true)

        ["rspec", "rspec[mcollective", "[mcollective]", 1, "rspec[]", "rspec-rspec[rspec]"].each do |resource|
          expect { Puppet_resourceValidator.validate(resource) }.to raise_error("'#{resource}' is not a valid resource name")
        end
      end
    end
  end
end
