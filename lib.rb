# SHARED LIBRARY OF FUNCTIONS

# sinatra help functions
helpers do
  def validate(username, password)
  end
  
  def is_logged_in?
    if session[:logged_in] == true and not session[:username].nil?
      return true
    else
      return false
    end
  end

  def forceSessionAuth
    if is_logged_in?
      @session = session
      return true
    else
      redirect '/login'
      return false
    end 
  end
  
  def clear_session
    session.clear
  end

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Pinch requires authentication")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    return true if is_logged_in? == true
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    if @auth.provided? && @auth.basic? && @auth.credentials && validate(@auth.credentials[0], @auth.credentials[1])
      session[:username] = @auth.username
    else
      return false
    end
  end

end
