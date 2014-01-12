get '/events' do
  haml :events
end

get '/api/events' do
  params = request.env['rack.request.query_hash']
  events = Event.all(params)
  puts events
  events[:events].each do |event|
    puts unless event.nil?
  end
end

get '/api/events/search' do
  # params = request.env['rack.request.query_hash']
end
