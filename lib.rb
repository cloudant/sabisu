# SHARED LIBRARY OF FUNCTIONS

# sinatra help functions
helpers do
  def validate(username, password)
    username == UI_USERNAME && password == UI_PASSWORD ? true : false
  end

  def logged_in?
    if NOAUTH == true || (session[:logged_in] == true && !session[:username].nil?)
      return true
    else
      return false
    end
  end

  def force_session_auth
    if logged_in?
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

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [UI_USERNAME, UI_PASSWORD]
  end

  def protected!
    unless authorized? || logged_in?
      response['WWW-Authenticate'] = "Basic realm='Sabisu requires authentication'"
      throw(:halt, [401, "Not authorized\n"])
    end
  end

end
