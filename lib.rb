# SHARED LIBRARY OF FUNCTIONS

# sinatra help functions
helpers do
  def validate(username, password)
    if username == UI_USERNAME and password == UI_PASSWORD
      return true
    else
      return false
    end
  end
  
  def is_logged_in?
    if NOAUTH == true or (session[:logged_in] == true and not session[:username].nil?)
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
      response['WWW-Authenticate'] = "Basic realm="Sabisu requires authentication""
      throw(:halt, [401, "Not authorized\n"])
    end
  end

end
