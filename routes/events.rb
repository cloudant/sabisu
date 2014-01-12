get '/events' do
  haml :events
end

get '/api/events' do
  params = request.env['rack.request.query_hash']
  events = Event.all(params)
  puts events
  events[:events].each do |event|
    unless event.nil?
      puts event
    end
  end
end

get '/api/events/search' do
  params = request.env['rack.request.query_hash']
end
