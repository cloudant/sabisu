# extend String class
class String
  def to_bool
    self == true || self =~ (/(true|t|yes|y|1)$/i) ? true : false
  end
end

# Sensu dashboard powered by Cloudant
module Sabisu
  # server class
  class Server
    if defined?(::CONFIG_FILE)
      CONFIG_FILE = ::CONFIG_FILE
    else
      CONFIG_FILE = {}
    end

    configure do
      # set the environment
      if defined?(SABISU_ENV)
        environment = SABISU_ENV
      else
        environment = CONFIG_FILE[:SABISU_ENV] || ENV['SABISU_ENV'] || 'production'
      end
      set :environment, environment.to_sym
      puts environment
    end

    configure :development do
      puts 'DEVELOPMENT ENVIRONMENT!!!'
      auth = CONFIG_FILE[:NOAUTH] || ENV['NOAUTH'] || true
      NOAUTH = auth.is_a?(String) ? auth.to_bool : auth

      # get SSL_ONLY, default to false
      use_ssl = CONFIG_FILE[:SSL_ONLY] || ENV['SSL_ONLY'] || false
      SSL_ONLY = use_ssl.is_a?(String) ? use_ssl.to_bool : use_ssl
    end

    configure :production do
      puts 'PRODUCTION ENVIRONMENT!!!'
      auth = CONFIG_FILE[:NOAUTH] || ENV['NOAUTH'] || false
      NOAUTH = auth.is_a?(String) ? auth.to_bool : auth

      # get SSL_ONLY, default to true
      use_ssl = CONFIG_FILE[:SSL_ONLY] || ENV['SSL_ONLY'] || true
      SSL_ONLY = use_ssl.is_a?(String) ? use_ssl.to_bool : use_ssl

      # don't show exceptions
      set :raise_errors, proc { false }
      set :show_exceptions, false
    end

    configure do
      use Rack::Session::Pool, expire_after: 2_592_000
      set :views, File.join(settings.root, 'templates')
      set :haml, format: :html5

      # enable heroku realtime logging;
      # see https://devcenter.heroku.com/articles/ruby#logging
      $stdout.sync = true

      PORT = CONFIG_FILE[:PORT] || ENV['PORT'] || 8080
      set :port, PORT

      user = CONFIG_FILE[:CLOUDANT_USER] || ENV['CLOUDANT_USER'] || nil
      password = CONFIG_FILE[:CLOUDANT_PASSWORD] || ENV['CLOUDANT_PASSWORD'] || nil
      url = CONFIG_FILE[:CLOUDANT_URL] || ENV['CLOUDANT_URL'] || nil
      current_db = CONFIG_FILE[:CLOUDANT_CURRENTDB] || ENV['CLOUDANT_CURRENTDB'] || nil
      history_db = CONFIG_FILE[:CLOUDANT_HISTORYDB] || ENV['CLOUDANT_HISTORYDB'] || nil

      CURRENT_DB = CouchRest.database(
        "https://#{user}:#{password}@#{url}/#{current_db}"
      )
      HISTORY_DB = CouchRest.database(
        "https://#{user}:#{password}@#{url}/#{history_db}"
      )

      # fields
      default_fields = [
        { name: 'client', path: 'client.name', facet: true, type: 'str', index: true },
        { name: 'check', path: 'check.name', facet: true, type: 'str', index: true },
        { name: 'status', path: 'check.status', facet: false, type: 'int', index: true },
        { name: 'state_change', path: 'check.state_change', facet: false, type: 'int',
          index: true },
        { name: 'occurrence', path: 'occurrences', facet: false, type: 'int', index: true },
        { name: 'issued', path: 'check.issued', facet: false, type: 'int', index: true },
        { name: 'output', path: 'check.output', facet: false, type: 'str', index: true }
      ]

      custom_fields = CONFIG_FILE[:CUSTOM_FIELDS] || ENV['CUSTOM_FIELDS'] || []
      if custom_fields.is_a?(String)
        custom_fields = JSON.parse(custom_fields, symbolize_names: true)
      end
      FIELDS = default_fields + custom_fields

      API_URL = CONFIG_FILE[:API_URL] || ENV['API_URL'] || 'localhost'
      use_api_ssl = CONFIG_FILE[:API_SSL] || ENV['API_SSL'] || false
      API_SSL = use_api_ssl.is_a?(String) ? use_api_ssl.to_bool : use_api_ssl
      API_PORT = CONFIG_FILE[:API_PORT] || ENV['API_PORT'] || 4567
      API_USER = CONFIG_FILE[:API_USER] || ENV['API_USER'] || nil
      API_PASSWORD = CONFIG_FILE[:API_PASSWORD] || ENV['API_PASSWORD'] || nil

      UI_USERNAME = CONFIG_FILE[:UILOGIN_USER] || ENV['UILOGIN_USER'] || 'guest'
      UI_PASSWORD = CONFIG_FILE[:UILOGIN_PASSWORD] || ENV['UILOGIN_PASSWORD'] || 'guest'

      if SSL_ONLY == true
        # force ssl connections only
        require 'rack-ssl-enforcer'
        use Rack::SslEnforcer
      end

      # create/update the design doc for sabisu to index the db
      Event.update_design_doc
    end
  end
end
