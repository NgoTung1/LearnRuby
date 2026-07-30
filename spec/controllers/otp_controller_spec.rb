require 'rails_helper'

RSpec.describe OtpController, type: :controller do
  let(:password) { "password" }
  let(:unverified_user) do
    user = User.create!(email: "unverified@gmail.com", password: password, is_verified: false)
    user.generate_otp!
    user
  end

  describe "POST #create (Xác thực OTP)" do
    context "Khi chưa đăng nhập (Cookie bị đứt/nil)" do
      it "Đá người dùng về trang Login" do
        post :create, params: { otp_code: "123456" }
        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("Hết phiên đăng nhập")
      end
    end

    context "Khi đã đăng nhập" do
      before do
        cookies.encrypted[:user_id] = unverified_user.id
      end

      it "Nhập SAI mã OTP -> Báo lỗi và không đổi is_verified" do
        post :create, params: { otp_code: "000000" } # Mã sai
        
        expect(flash.now[:alert]).to include("Mã OTP không đúng")
        expect(response).to render_template(:new)
        expect(unverified_user.reload.is_verified?).to be false
      end

      it "Nhập ĐÚNG mã OTP -> Cập nhật is_verified = true và chuyển sang trang chủ" do
        post :create, params: { otp_code: unverified_user.otp_code } # Mã đúng
        
        expect(unverified_user.reload.is_verified?).to be true
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Xác thực thành công")
      end
    end
  end

  describe "POST #resend (Gửi lại OTP)" do
    before do
      cookies.encrypted[:user_id] = unverified_user.id
    end

    it "Gửi lại OTP mới và bắn email" do
      expect {
        post :resend
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(flash.now[:alert]).to eq("Đã gửi lại OTP.")
      expect(response).to render_template(:new)
    end
  end
end