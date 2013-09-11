configure do
  use Rack::Session::Pool, :expire_after => 2592000
  set :session_secret, 'help me obi wan kenobi youre my only hope!'
  set :views, File.join(settings.root, 'templates')
  set :haml, :format => :html5

  # enable heroku realtime logging;
  # see https://devcenter.heroku.com/articles/ruby#logging
  $stdout.sync = true
end

configure :production, :development do
  # this is defined by Heroku in production, by your .env file in development

end

configure :development do
  puts "DEVELOPMENT ENVIRONMENT!!!"
end

configure :production do
  puts "PRODUCTION ENVIRONMENT!!!"

  # force ssl connections only
  require 'rack-ssl-enforcer'
  use Rack::SslEnforcer

  # don't show exceptions
  set :raise_errors, Proc.new { false }
  set :show_exceptions, false
end

configure :test do
end
