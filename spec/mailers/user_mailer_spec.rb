require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe "otp_email" do
    let(:user) do
      user = User.create!(email: "test_mailer@gmail.com", password: "password")
      user.generate_otp!
      user
    end

    let(:mail) { UserMailer.otp_email(user) }

    it "Gửi đúng địa chỉ email nhận" do
      expect(mail.to).to eq([user.email])
    end

    it "Tiêu đề email chứa thông tin xác thực" do
      expect(mail.subject).to include("Mã xác thực OTP của bạn") 
    end

    it "Nội dung email phải chứa mã OTP vừa tạo" do
      expect(mail.body.encoded).to include(user.otp_code)
    end
  end
end