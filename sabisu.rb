# load gems
require 'sinatra'
require 'redis'
require 'couchrest'
require 'uri'
require 'cgi'
require 'json'
require 'digest'

# load configuration settings
require_relative 'config'

# load shared library
require_relative 'lib'

# load classes
require_relative 'classes/init'

# URL Routing
before '*' do
  forceSessionAuth
end
