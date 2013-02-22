$: << File.join([File.dirname(__FILE__), "lib"])

require 'rubygems'
require 'rspec'
require 'mcollective'
require 'mcollective/test'
require 'rspec/mocks'
require 'mocha'
require 'tempfile'
require 'fileutils'
require 'ostruct'
require 'json'

# fake puppet enough just to get by without requiring it to run tests
module Puppet
  class Type;end
  class Transaction;end
  class Transaction::Report;end
  class Util;end
  class Util::Log;end
  class Resource;end
  class Resource::Catalog;end

  def self.[](what)
    what.to_s
  end

  def self.settings(settings=nil)
    if settings
      @settings = OpenStruct.new(settings)
    else
      @settings ||= OpenStruct.new(:app_defaults_initialized? => true)
    end
  end

  def self.features(features=nil)
    if features
      @features = OpenStruct.new(features)
    else
      @features ||= OpenStruct.new(:microsoft_windows? => false)
    end
  end
end

RSpec.configure do |config|
  config.mock_with :mocha
  config.include(MCollective::Test::Matchers)

  config.before :each do
    MCollective::PluginManager.clear
  end
end
