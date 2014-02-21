#!ruby
source 'https://rubygems.org'

group :test do
  gem 'rake'
  gem 'rspec', '~> 2.11.0'
  gem 'mocha', '~> 0.10.0'
  gem 'mcollective-test'
end

mcollective_version = ENV['MCOLLECTIVE_GEM_VERSION']

if mcollective_version
  gem 'mcollective-client', mcollective_version, :require => false
else
  gem 'mcollective-client', :require => false
end
