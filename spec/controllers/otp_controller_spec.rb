require 'rails_helper'

RSpec.describe OtpsController, type: :controller do
  include ActiveJob::TestHelper
  let(:password) { "password" }
  let(:unverified_user) do
    user = User.create!(email: "unverified@gmail.com", password: password, password_confirmation: password, is_verified: false)
    user.generate_otp!
    user
  end

  describe "POST #create (Xác thực OTP)" do
    context "Khi chưa đăng nhập (Cookie bị đứt/nil)" do
      it "Đưa người dùng về trang Login" do
        post :create, params: { otp_code: "123456" }
        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("Hết phiên đăng nhập")
      end
    end

    context "Khi đã đăng nhập" do
      before do
        cookies.encrypted[:user_id] = unverified_user.id
      end

      it "Nhập sai mã OTP -> Báo lỗi và không đổi is_verified" do
        post :create, params: { otp_code: "000000" }
        
        expect(flash.now[:alert]).to include("Mã OTP không đúng hoặc đã hết hạn. Vui lòng đăng nhập lại")
        expect(response).to have_http_status(200)
        expect(unverified_user.reload.is_verified?).to be false
      end

      it "Nhập đúng mã OTP -> Cập nhật is_verified = true và chuyển sang trang chủ" do
        post :create, params: { otp_code: unverified_user.otp_code }
        
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

    context "Khi đã đủ 2 phút chờ" do
      before do
        unverified_user.update(otp_expires_at: 7.minutes.from_now)
      end

      it "Gửi lại OTP mới và bắn email thành công" do
        perform_enqueued_jobs do
          expect {
            post :resend
          }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end

        expect(flash.now[:alert]).to eq("Đã gửi lại OTP.")
        expect(response).to have_http_status(200)
      end
    end

    context "Khi chưa đủ 2 phút chờ" do
      it "Báo lỗi yêu cầu chờ 2 phút và không gửi lại email" do
        perform_enqueued_jobs do
          expect {
            post :resend
          }.not_to change { ActionMailer::Base.deliveries.count }
        end

        expect(flash.now[:alert]).to eq("Vui lòng chờ 2 phút trước khi gửi lại")
        expect(response).to have_http_status(200)
      end
    end
  end
end