require 'net/http'
require 'timeout'
require 'base64'
require 'json'
require 'uri'

module Puppet::Parser::Functions
  newfunction(:consulr_kv, :type => :rvalue) do |args|

    # Default config
    default_config = {
      'uri'           => 'http://localhost:8500',
      'nodes_prefix'  => 'nodes',
      'facter_prefix' => 'hostname',
      'value_only'    => true,
      'base64_decode' => true,
      'ignore_404'    => true,
      'token'         => false,
      'timeout'       => 5,
    }

    # Required config options (for future use)
    required_config = []

    # User config
    user_config = args.first ? args.first : Hash.new

    # final config
    config = default_config.merge(user_config)

    # Missing config
    missing_config = required_config.reject {|i| config.has_key?(i)}

    raise Puppet::ParseError, "Consulr missing config: #{missing_config.join(', ')}" unless missing_config.empty?

    # lookupvar returns 'nil' if the fact doesn't exist...
    prefix = lookupvar(config['facter_prefix'])

    # ...so lets raise hell if thats the case.
    raise Puppet::ParseError, "Consulr facter prefix not found: #{config['facter_prefix']}" if prefix.nil?

    consulr = Hash.new

    begin
      Timeout::timeout(config['timeout']) do
        # Build and parse URI
        build_uri = "#{config['uri']}/v1/kv/#{config['nodes_prefix']}/#{prefix}?recurse"
        build_uri << "&token=#{config['token']}" if config['token']

        response = Net::HTTP.get_response(URI.parse(build_uri))

        # Following HTTP codes will not raise an exception
        ignore_http_codes = ['200']

        # Option to ignore 404
        ignore_http_codes << '404' if config['ignore_404']

        raise Puppet::ParseError, "Consulr HTTP error: #{config['uri']}/v1/kv/#{config['nodes_prefix']}/#{prefix}/ (#{response.code}: #{response.message})" unless ignore_http_codes.include?(response.code)
        data = JSON.parse(response.body) rescue []

        # Iterate though the keys and put them in a hash 
        data.each do |kv|

          # We are determining 2 things here:
          # 1) Whether to send back only value or the entire hash or
          # 2) Whether to decode the value before sending it back
          if config['value_only']
            result = config['base64_decode'] ? Base64.decode64(kv['Value']) : kv['Value']
          else
            kv['Value'] = Base64.decode64(kv['Value']) if config['base64_decode']
            result = kv
          end

          # Finally remove <nodes_prefix>/<prefix> from the
          # path and assign that value as the new key
          consulr[kv['Key'].sub(/^#{config['nodes_prefix']}\/#{prefix}\//, "")] = result
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
