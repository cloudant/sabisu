get '/events' do
  haml :events
end

get '/events/:client' do
  haml :events_client, :locals => { :client => params[:client] }
end

get '/events/:client/:check' do
  haml :events_client_check, :locals => { :client => params[:client], :check => params[:check] }
end
