# api routes
module Sabisu
  # server class
  class Server
    get '/api/events' do
      params = request.env['rack.request.query_hash']
      events = Event.all(params)
      JSON.pretty_generate(events)
    end

    get '/api/events/search' do
      params = request.env['rack.request.query_hash']
      if params.key?('query')
        query = params['query']
        params.delete('query')
      else
        return 'Must supply \'query\' parameter'
      end
      events = Event.search(query, params)
      JSON.pretty_generate(events)
    end

    get '/api/events/stale' do
      params = request.env['rack.request.query_hash']
      stale = Event.stale(params)
      JSON.pretty_generate(stale: stale)
    end

    get '/api/events/changes' do
      params = request.env['rack.request.query_hash']
      JSON.pretty_generate(CURRENT_DB.changes(params))
    end

    get '/api/configuration/fields' do
      JSON.pretty_generate(FIELDS)
    end
  end
end
