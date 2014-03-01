configure do
  use Rack::Session::Pool, expire_after: 2_592_000
  set :session_secret, 'help me obi wan kenobi youre my only hope!'
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
  #require 'rack-ssl-enforcer'
  #use Rack::SslEnforcer

  # don't show exceptions
  set :raise_errors, Proc.new { false }
  set :show_exceptions, false
end

configure :production, :development do
  # this is defined by Heroku in production, by your .env file in development
  CURRENT_DB = CouchRest.database!(
    "https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@" +
    "#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_CURRENTDB']}"
  )
  HISTORY_DB = CouchRest.database!(
    "https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@" +
    "#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_HISTORYDB']}"
  )

  # connect to redis
  API_URL = ENV['API_URL'] if ENV['API_URL']
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
