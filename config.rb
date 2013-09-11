configure do
  use Rack::Session::Pool, :expire_after => 2592000
  set :session_secret, 'help me obi wan kenobi youre my only hope!'
  set :views, File.join(settings.root, 'templates')
  #set :public_folder, File.join(settings.root, 'public')
  set :haml, :format => :html5

  # enable heroku realtime logging;
  # see https://devcenter.heroku.com/articles/ruby#logging
  $stdout.sync = true
end

configure :development do
  puts "DEVELOPMENT ENVIRONMENT!!!"
  NOAUTH = true
end

configure :production do
  puts "PRODUCTION ENVIRONMENT!!!"
  NOAUTH = false

  # force ssl connections only
  require 'rack-ssl-enforcer'
  use Rack::SslEnforcer

  # don't show exceptions
  set :raise_errors, Proc.new { false }
  set :show_exceptions, false
end

configure :production, :development do
  # this is defined by Heroku in production, by your .env file in development
  CURRENT_DB = CouchRest.database!("https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_CURRENTDB']}")
  HISTORY_DB = CouchRest.database!("https://#{ENV['CLOUDANT_USER']}:#{ENV['CLOUDANT_PASSWORD']}@#{ENV['CLOUDANT_URL']}/#{ENV['CLOUDANT_HISTORYDB']}")
  
  UI_USERNAME = ENV['UILOGIN_USER']
  UI_PASSWORD = ENV['UILOGIN_PASSWORD']

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
