class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
  
    if @user.save
      @user.generate_otp!
      session[:registration_user_id] = @user.id
      
      redirect_to otp_path, notice: "Đăng ký thành công! Vui lòng kiểm tra email để lấy mã OTP."
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end