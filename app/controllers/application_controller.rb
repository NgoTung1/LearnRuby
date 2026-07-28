class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?
  def current_user
    if cookies.encrypted[:user_id]
      @current_user ||= User.find_by(id: cookies.encrypted[:user_id])
    end
  end

  def logged_in?
    current_user.present?
  end
end
