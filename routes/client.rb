get '/clients/:client' do
  haml :client, :locals => { :client => params[:client] }
end

get '/clients/:client/:check' do
  haml :client_check, :locals => { :client => params[:client], :check => params[:check] }
end
