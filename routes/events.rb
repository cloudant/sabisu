get '/events' do
  events = CURRENT_DB.view('sort/client', :skip => 5, :limit => 10, :descending => true, :include_docs => true)['rows']
  haml :events, :locals => { :events => events }
end

get '/events/:client' do
  haml :event_client, :locals => { :client => params[:client] }
end

get '/events/:client/:check' do
  haml :event_client_check, :locals => { :client => params[:client], :check => params[:check] }
end
