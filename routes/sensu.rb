def sensu(request)
  sensu = Sensu.new
  tmp_path = request.path_info.split('/')
  tmp_path.delete_at(1)
  path = tmp_path.join('/')
  puts path
  opts = {
    path: path,
    method: request.request_method
  }
  begin
    opts[:payload] = JSON.parse(request.body.read)
  # rubocop:disable HandleExceptions
  rescue
    # do nothing
  # rubocop:enable HandleExceptions
  end
  sensu.request(opts)
end

get '/sensu/*' do
  res = sensu(request)
  status res.code
  headers 'content-type' => 'application/json'
  body res.body
end

post '/sensu/*' do
  res = sensu(request)
  print res
  status res.code
  headers 'content-type' => 'application/json'
  body res.body
end

put '/sensu/*' do
  res = sensu(request)
  status res.code
  headers 'content-type' => 'application/json'
  body res.body
end

delete '/sensu/*' do
  res = sensu(request)
  status res.code
  headers 'content-type' => 'application/json'
  body res.body
end
