class UserMailer < ApplicationMailer  
  default from: 'Weather on Rails <no-reply@wor.com>'

  def otp_email(user)
    @user = user
    mail(to: @user.email, subject: "Mã xác thực OTP của bạn")
  end
end