class PasswordResetsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email])

    if user
      user.generate_reset_password_token!
      UserMailer.reset_password_email(user).deliver_later
    end

    redirect_to login_path,
      notice: "Nếu email tồn tại trong hệ thống, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu."
  end

  def edit
    @user = User.find_by(reset_password_token: params[:token])

    if @user.nil? || !@user.reset_password_token_valid?
      redirect_to forgot_password_path,
        alert: "Liên kết đã hết hạn hoặc không hợp lệ. Vui lòng thử lại."
    end
  end

  def update
    @user = User.find_by(reset_password_token: params[:token])

    if @user.nil? || !@user.reset_password_token_valid?
      redirect_to forgot_password_path,
        alert: "Liên kết đã hết hạn hoặc không hợp lệ."
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Mật khẩu xác nhận không trùng khớp."
      render :edit
      return
    end

    if params[:password].length < 6
      flash.now[:alert] = "Mật khẩu phải có ít nhất 6 ký tự."
      render :edit
      return
    end

    @user.password = params[:password]
    @user.clear_reset_password_token!
    @user.save!(validate: false)

    redirect_to login_path,
      notice: "Mật khẩu đã được đặt lại thành công! Vui lòng đăng nhập."
  end
end
