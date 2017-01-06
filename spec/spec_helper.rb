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
  class Transaction::Report
   attr_reader :logs
   def <<(msg)
     @logs << msg
     self
   end
   def initialize
     @logs = []
   end
   def initialize_from_hash(data)
     @logs = data['logs'].map do |record|
       Puppet::Util::Log.from_pson(record)
     end
   end
  end
  class Util;end
  class Util::Log
    attr_reader :level, :message, :time, :source
    @loglevel = 2
    @levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
    def self.level
      @levels[@loglevel]
    end
    def self.levels
      @levels.dup
    end
    def self.from_pson(data)
      obj = allocate
      obj.initialize_from_hash(data)
      obj
    end
    def self.level=(level)
      level = level.intern unless level.is_a?(Symbol)

      raise Puppet::DevError, "Invalid loglevel #{level}" unless @levels.include?(level)

      @loglevel = @levels.index(level)
    end
  end
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

  # duplicated from marionette_collective/lib/mcollective/util
  def self.windows?
    !!(RbConfig::CONFIG['host_os'] =~ /mswin|win32|dos|mingw|cygwin/i)
  end
end

RSpec.configure do |config|
  config.mock_with :mocha
  config.include(MCollective::Test::Matchers)

  config.before :each do
    MCollective::PluginManager.clear
  end
end
