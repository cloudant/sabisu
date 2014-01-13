get '/events' do
  haml :events
end

get '/api/events' do
  params = request.env['rack.request.query_hash']
  events = Event.all(params)
  event_json = []
  events[:events].each do |event|
    event_json << event.to_json
  end
  event_json
end

get '/api/events/search' do
  params = request.env['rack.request.query_hash']
  pp params
  if params.key?('query')
    query = params['query']
    params.delete('query')
  else
    return 'Must supply \'query\' parameter'
  end
  events = Event.search(query, params)
  event_json = []
  events[:events].each do |event|
    event_json << event.to_json
  end
  event_json
end
