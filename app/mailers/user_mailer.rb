class UserMailer < ApplicationMailer  
  default from: ENV.fetch('MAIL_FROM') { 'Weather on Rails <onboarding@resend.dev>' }

  def otp_email(user)
    @user = user
    mail(to: @user.email, subject: "Mã xác thực OTP của bạn")
  end

  def reset_password_email(user)
    @user = user
    @reset_url = "#{root_url}reset_password?token=#{user.reset_password_token}"
    mail(to: @user.email, subject: "Đặt lại mật khẩu - Weather on Rails")
  end
end