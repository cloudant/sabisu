# sensu routes
module Sabisu
  # server class
  class Server
    def sensu(request)
      sensu = Sensu.new
      tmp_path = request.path_info.split('/')
      tmp_path.delete_at(1)
      path = tmp_path.join('/')
      opts = {
        path: path,
        method: request.request_method,
        ssl: API_SSL
      }
      begin
        opts[:payload] = JSON.parse(request.body.read) if request.post?
      rescue StandardError => e
        puts "unable to parse: #{request.body.read}"
      end
      sensu.request(opts)
    end

    route :get, :post, '/sensu/stashes' do
      res = sensu(request)
      status res.code
      headers 'content-type' => 'application/json'
      body res.body
    end

    route :get, :post, :delete, '/sensu/stashes/*' do
      res = sensu(request)
      status res.code
      headers 'content-type' => 'application/json'
      body res.body
    end

    post '/sensu/resolve' do
      res = sensu(request)
      status res.code
      headers 'content-type' => 'application/json'
      body res.body
    end
  end
end
