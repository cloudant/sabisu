get '/api/events' do
  params = request.env['rack.request.query_hash']
  events = Event.all(params)
  events[:events].map! do |event|
    event.to_json
  end
  JSON.pretty_generate(events)
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
  events[:events].map! do |event|
    event.to_json
  end
  JSON.pretty_generate(events)
end
