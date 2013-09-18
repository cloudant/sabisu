get '/api/events' do
  params = request.env['rack.request.query_hash']
end

get '/api/client/:name' do
  name = params[:name]
  
end
