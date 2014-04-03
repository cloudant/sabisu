#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/https'
require 'uri'
require 'json'

# check stashes class
class CheckStashes < Sensu::Plugin::Check::CLI
  option :api,
         short: '-a URL',
         long: '--api URL',
         description: 'sensu api url',
         default: 'http://localhost:4567'

  option :user,
         short: '-u USER',
         long: '--user USER',
         description: 'sensu api user'

  option :password,
         short: '-p PASSOWRD',
         long: '--password PASSWORD',
         description: 'sensu api password'

  def http_request(url, method, user, pw)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout, http.open_timeout = 15, 5
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    case method
    when 'Get'
      req =  Net::HTTP::Get.new(uri.request_uri)
    when 'Delete'
      req =  Net::HTTP::Delete.new(uri.request_uri)
    end
    req.basic_auth(user, pw) if user && pw

    http.request(req)
  end

  def api_request(resource, method)
    http_request(
      config[:api] + resource,
      method,
      config[:user],
      config[:password]
    )
  rescue Timeout::Error
    puts 'HTTP request has timed out.'
    critical 'HTTP request has timed out.'
    exit
  rescue StandardError => e
    puts "An HTTP error occurred. #{e}"
    critical 'HTTP request has timed out.'
    exit
  end

  def stashes
    resource = '/stashes'
    res = api_request(resource, 'Get')
    if response?(res.code)
      JSON.parse(res.body, symbolize_names: true)
    else
      warning 'Failed to get stashes'
    end
  end

  def events
    resource = '/events'
    res = api_request(resource, 'Get')
    if response?(res.code)
      JSON.parse(res.body, symbolize_names: true)
    else
      warning 'Failed to get events'
    end
  end

  def response?(code)
    %w(200 204).include?(code)
  end

  def delete_stash(path)
    resource = "/stashes/#{path}"
    res = api_request(resource, 'Delete')
    if response?(res.code)
      puts "STASH: #{resource} was deleted"
    else
      warning "Deletion of #{resource} failed."
    end
  end

  # rubocop:disable CyclomaticComplexity
  def process_stashes(stashes)
    my_events = events
    stashes.each do |s|
      next unless s[:path] =~ /^silence\//

      if s[:content].key?(:timestamp) &&
      (Time.now.to_i - s[:content][:timestamp].to_i) > 3600 &&
      s[:content][:expiration] == 'resolve'
        _, client, check = s[:path].split('/')
        if (check.nil? && !my_events.find { |e| e[:client] == client }) ||
           (check && !my_events.find { |e| e[:client] == client && e[:check] == check })
          delete_stash(s[:path])
        end
      end
    end
  end
  # rubocop:enable CyclomaticComplexity

  def run
    process_stashes(stashes)
    ok 'Stashes have been processed'
  end
end
