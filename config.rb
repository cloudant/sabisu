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
  
  # connect to redis
  API_URL = ENV['API_URL'] if ENV['API_URL']
  API_PORT = ENV['API_PORT'] if ENV['API_PORT']
  API_USER = ENV['API_USER'] if ENV['API_USER']
  API_PASSWORD = ENV['API_PASSWORD'] if ENV['API_PASSWORD']

  UI_USERNAME = ENV['UILOGIN_USER']
  UI_PASSWORD = ENV['UILOGIN_PASSWORD']
  
  # create the design doc needed for sorting if necessary
  #sort_fields = { :client => 'client.name', :check => 'check.name', :issued => 'check.issued' }
  #sort_views = {}
  #sort_fields.to_a.permutation.to_a.collect { |x| x.take(2) }.uniq.each { |p| # crazy permutation function
  #  sort_name = p.collect { |pp| pp.first.to_s }.join('_').to_sym
  #  sort_key = p.collect { |pp| "doc.#{pp.last}" }.join(', ')
  #  sort_views[sort_name] = { :map => "function(doc) { if (doc.name) emit([#{sort_key}], null);  }" } 
  #}
  #begin
  #  doc = CURRENT_DB.get('_design/sort')
  #  if doc[:views] != sort_views
  #    CURRENT_DB.save_doc({ '_id' => '_design/sort', :views => sort_views })
  #  end
  #rescue RestClient::Conflict
  #  # ignore
  #rescue RestClient::ResourceNotFound
  #  CURRENT_DB.save_doc({ '_id' => '_design/sort', :views => sort_views })
  #end
  
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
