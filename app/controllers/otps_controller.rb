class OtpsController < ApplicationController
  def new
  end
  def create
    @user = User.find_by(id: session[:registration_user_id])
    if @user.nil?
      redirect_to login_path, notice: "Hết phiên đăng nhập, vui lòng đăng nhập lại"
    else 
      if @user.check_otp?(params[:otp]) == false
        flash.now[:alert] = "Mã OTP không đúng. Vui lòng đăng nhập lại"
      else 
        @user.update(is_verified = true)
        cookies.encrypted[:user_id] = {
          value: @user.id,
          expires: 30.minutes.from_now,
          httponly: true
        }
        session.delete(:registration_user_id)
        redirect_to root_path, notice: "Xác thực thành công"

      end
    end

  end

end