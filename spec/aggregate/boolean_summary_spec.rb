#!/usr/bin/env rspec

require 'spec_helper'
require File.join(File.dirname(__FILE__), File.join('../../', 'aggregate', 'boolean_summary.rb'))

module MCollective
  class Aggregate
    describe Boolean_summary do
      let(:boolean) { Boolean_summary.new(:test, nil, nil, :test_action) }

      describe '#startup_hook' do
        it 'should correctly configure the plugin and set default argument values if none are supplied' do
          boolean.result.should == {:value => {}, :type => :collection, :output => :test}
          boolean.aggregate_format.should == "%5s = %s"
          boolean.arguments.should == {true => 'True', false => 'False'}
        end

        it 'should correctly set a custom format' do
          bool = Boolean_summary.new(:test, nil, 'rspec', :test_action)
          bool.aggregate_format.should == 'rspec'
        end

        it 'should correcrly set custom arguments' do
          bool = Boolean_summary.new(:test, {true => 'rspec_true', false => 'rspec_false'}, 'rspec', :test_action)
        end
      end

      describe '#process_result' do
        it 'should process a single value' do
          boolean.expects(:add_value).once
          boolean.process_result(true, nil)
        end

        it 'should process multiple values' do
          boolean.expects(:add_value).times(3)
          boolean.process_result([true, true, true], nil)
        end
      end

      describe '#add_value' do
        it 'should add the correct truth value to the modified field' do
          boolean.add_value(true)
          boolean.add_value(true)
          boolean.add_value(true)
          boolean.add_value(false)
          boolean.add_value(false)
          boolean.result[:value].should == {'True' => 3, 'False' => 2}
        end
      end
    end
  end
end
