require 'net/https'
require 'json'

# make api requests to sensu
class Sensu
  def request(opts)
    http = Net::HTTP.new(API_URL, API_PORT)
    http.read_timeout = 15
    http.open_timeout = 5
    if API_SSL && API_SSL.to_s.downcase == 'true'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    proxy_header = { 'api-proxy' => 'true' }
    case opts[:method]
    when 'get'.upcase
      req =  Net::HTTP::Get.new(opts[:path], proxy_header)
    when 'delete'.upcase
      req =  Net::HTTP::Delete.new(opts[:path], proxy_header)
    when 'post'.upcase
      req =  Net::HTTP::Post.new(
        opts[:path],
        proxy_header.merge!('Content-Type' => 'application/json')
      )
      req.body = opts[:payload].to_json
    end
    req.basic_auth(API_USER, API_PASSWORD) if defined?(API_USER) && defined?(API_PASSWORD)
    http.request(req)
  end

  def response(code, body, command = nil)
    case code
    when '200'
      JSON.parse(body)
    when '201'
      puts 'The stash has been created.' if command == 'stashes' || command == 'silence'
    when '202'
      puts 'The item was submitted for processing.'
    when '204'
      puts 'Sensu is healthy' if command == 'health'
      puts 'The item was successfully deleted.' if command == 'aggregates' || command == 'stashes'
    when '400'
      puts 'The payload is malformed.'.color(:red)
    when '401'
      puts 'The request requires user authentication.'.color(:red)
    when '404'
      puts 'The item did not exist.'.color(:cyan)
    else
      if command == 'health'
        puts 'Sensu is not healthy.'.color(:red)
      else
        puts 'There was an error while trying to complete your request. ' +
             "Response code: #{code}".color(:red)
      end
    end
  end
end
