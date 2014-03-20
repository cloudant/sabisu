configure do
  use Rack::Session::Pool, expire_after: 2_592_000
  set :views, File.join(settings.root, 'templates')
  # set :public_folder, File.join(settings.root, 'public')
  set :haml, format: :html5

  # enable heroku realtime logging;
  # see https://devcenter.heroku.com/articles/ruby#logging
  $stdout.sync = true
end

configure :development do
  puts 'DEVELOPMENT ENVIRONMENT!!!'
  NOAUTH = true
end

configure :production do
  puts 'PRODUCTION ENVIRONMENT!!!'
  NOAUTH = false

  # force ssl connections only
  require 'rack-ssl-enforcer'
  # use Rack::SslEnforcer

  # don't show exceptions
  set :raise_errors, proc { false }
  set :show_exceptions, false
end

configure :production, :development do
  # this is defined by Heroku in production, by your .env file in development
  CURRENT_DB = CouchRest.database!(
    "https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@" \
    "#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_CURRENTDB']}"
  )
  HISTORY_DB = CouchRest.database!(
    "https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@" \
    "#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_HISTORYDB']}"
  )

  # fields
  FIELDS = [
    { name: 'client', path: 'client.name', facet: true, type: 'str', index: true },
    { name: 'check', path: 'check.name', facet: true, type: 'str', index: true },
    { name: 'status', path: 'check.status', facet: false, type: 'int', index: true },
    { name: 'state_change', path: 'check.state_change', facet: false, type: 'int', index: true },
    { name: 'occurrence', path: 'occurrences', facet: false, type: 'int', index: true },
    { name: 'issued', path: 'check.issued', facet: false, type: 'int', index: true },
    { name: 'output', path: 'check.output', facet: false, type: 'str', index: true }
  ]

  FIELDS += JSON.parse(ENV['CUSTOM_FIELDS'], symbolize_names: true) if ENV['CUSTOM_FIELDS']

  # connect to redis
  API_URL = ENV['API_URL'] if ENV['API_URL']
  API_SSL = ENV['API_URL'] || false
  API_PORT = ENV['API_PORT'] if ENV['API_PORT']
  API_USER = ENV['API_USER'] if ENV['API_USER']
  API_PASSWORD = ENV['API_PASSWORD'] if ENV['API_PASSWORD']

  UI_USERNAME = ENV['UILOGIN_USER']
  UI_PASSWORD = ENV['UILOGIN_PASSWORD']

  # create the design doc if needed for retrieving events
  Event.update_design_doc

  if ENV['NOAUTH']
    if ENV['NOAUTH'] == 'true'
      NOAUTH = true
    else
      NOAUTH = false
    end
  end
end

configure :test do
  # run tests
end
