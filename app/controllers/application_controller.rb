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

  def require_verified_user
    if logged_in? && current_user.is_verified? == false
      redirect_to otp_path, alert: "Tài khoản của bạn chưa được xác thực, vui lòng xác thực trước"
    end
  end
end
