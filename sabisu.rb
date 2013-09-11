# load gems
require 'sinatra'
require 'redis'
require 'couchrest'
require 'cgi'
require 'json'

# load configuration settings
require_relative 'config'

# load shared library
require_relative 'lib'

# load classes
require_relative 'classes/init'

# URL Routing
before '/:name' do
  unless params[:name] == "login"
    forceSessionAuth
  end
end

get '/' do
  redirect "/login"
end

get '/login' do
  if session[:logged_in] = true and not session[:username].nil?
    redirect "/events"
  else
    clear_session
    haml :login, :locals => { :remember_me => session[:remember_me] }
  end
end

get '/events' do
  haml :events
end
