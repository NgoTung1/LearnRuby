class OtpsController < ApplicationController
  def new
  end
  def create
    @user = current_user
    if @user.nil?
      redirect_to login_path, notice: "Hết phiên đăng nhập, vui lòng đăng nhập lại"
    else 
      if @user.check_otp?(params[:otp_code]) == false
        flash.now[:alert] = "Mã OTP không đúng hoặc đã hết hạn. Vui lòng đăng nhập lại"
        render :new
      else 
        @user.update(is_verified: true)
        redirect_to root_path, notice: "Xác thực thành công"
      end
    end
  end
  def resend
    @user = current_user
    if @user.nil?
      redirect_to login_path, notice: "Hết phiên đăng nhập, vui lòng đăng nhập lại."
    elsif @user.resend_otp? == true
      @user.generate_otp!
      flash.now[:alert] = "Đã gửi lại OTP."
      render :new
    else
      flash.now[:alert] = "Vui lòng chờ 2 phút trước khi gửi lại"
      render :new
    end
  end
end