# event routes
module Sabisu
  # server class
  class Server
    get '/events' do
      haml :events
    end
  end
end
