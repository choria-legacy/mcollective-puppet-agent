#!ruby
source 'https://rubygems.org'

group :test do
  # Pin json for Ruby < 2.0.0
  gem 'json', '~> 1.8.3'
  gem 'rake', '~> 10.4'
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
