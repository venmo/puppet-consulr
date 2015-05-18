source 'https://rubygems.org'

gem "base64"
gem "net/http"
gem "net/https"
gem "timeout"
gem "uri"
gem "json", '>=1.1.1'
puppetversion = ENV.key?('PUPPET_VERSION') ? "= #{ENV['PUPPET_VERSION']}" : ['>= 3.3']
gem 'puppet', puppetversion
gem 'facter', '>= 1.7.0'
