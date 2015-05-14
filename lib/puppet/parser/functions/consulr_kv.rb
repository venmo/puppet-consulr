require 'net/http'
require 'timeout'
require 'base64'
require 'json'
require 'uri'

module Puppet::Parser::Functions
  newfunction(:consulr_kv, :type => :rvalue) do |args|

    # Lets define some customizable vars
    uri = args[0] # e.x. http://localhost:8500 (no trailing slash)
    facter_prefix_key = args[1] # The prefix key unique to each instance

    # Lets ensure both params are passed
    raise Puppet::ParseError, 'both uri and facter prefix key are required' if [uri, facter_prefix_key].include?(nil)
    
    # lookupvar returns 'nil' if the fact doesn't exist...
    prefix = lookupvar(facter_prefix_key)

    # ...so lets raise hell if thats the case.
    raise Puppet::ParseError, 'prefix fact not found' if prefix.nil?

    consulr = Hash.new

    begin
      Timeout::timeout(5) do
        # Get all the keys with facter prefix key
        uri = URI.parse("#{uri}/v1/kv/#{prefix}?recurse")
        response = Net::HTTP.get_response(uri)

	raise "HTTP error: #{prefix}/ #{response.code} #{response.message}" unless response.code == '200'
	data = JSON.parse(response.body)

        # Iterate though the keys and put them in a hash 
        data.each do |kv|
          # Replace only the first occurence of '<facter_prefix_key>/'
          # with blank so when calling in puppet we can omit the facter prefix key.
          # For example:
          # $consul['django_version'] instead of $consul['i-a8caf087/django_version']
          # but this is OK: $consul['haproxy/webs/i-a8caf087/version']
          consulr[kv['Key'].sub(/^#{prefix}\//, "")] = Base64.decode64(kv['Value'])
        end
      end
    rescue Timeout::Error => e
      raise Puppet::ParseError, "Consulr timed out: #{e.message}"

    rescue => e
      raise Puppet::ParseError, "Consulr exception: #{e.message}"

    end

    return consulr
  end
end
