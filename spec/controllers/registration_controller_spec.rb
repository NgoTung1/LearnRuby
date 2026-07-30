require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  include ActiveJob::TestHelper

  describe "GET #new" do
    it "Hiển thị trang đăng ký thành công" do
      get :new
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    context "Khi nhập thông tin hợp lệ" do
      let(:valid_params) do
        { user: { email: "newuser@gmail.com", password: "password", password_confirmation: "password" } }
      end

      it "Đăng ký thành công: tạo user, gửi email OTP, lưu cookie và redirect" do
        perform_enqueued_jobs do
          expect {
            post :create, params: valid_params
          }.to change(User, :count).by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)
        end

        user = User.find_by(email: "newuser@gmail.com")
        expect(cookies.encrypted[:user_id]).to eq(user.id)
        expect(response).to redirect_to(otp_path)
        expect(flash[:notice]).to include("Đăng ký thành công")
      end
    end

    context "Khi đăng ký bằng email ĐÃ TỒN TẠI trong hệ thống" do
      before do
        User.create!(email: "duplicate@gmail.com", password: "password", password_confirmation: "password")
      end

      let(:duplicate_email_params) do
        { user: { email: "duplicate@gmail.com", password: "password", password_confirmation: "password" } }
      end

      it "Không tạo thêm user mới và trả về thông báo lỗi email trùng lặp" do
        expect {
          post :create, params: duplicate_email_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(200)
        user_in_controller = controller.instance_variable_get(:@user)
        expect(user_in_controller.errors[:email]).to include("đã tồn tại trong hệ thống")
      end
    end

    context "Khi nhập mật khẩu xác nhận KHÔNG KHỚP" do
      let(:mismatched_password_params) do
        { user: { email: "mismatch@gmail.com", password: "password123", password_confirmation: "password999" } }
      end

      it "Không tạo user mới và trả về thông báo lỗi mật khẩu không trùng khớp" do
        expect {
          post :create, params: mismatched_password_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(200)
        user_in_controller = controller.instance_variable_get(:@user)
        expect(user_in_controller.errors[:password_confirmation]).to include("xác nhận không trùng khớp")
      end
    end

    context "Khi nhập thiếu email" do
      let(:invalid_params) do
        { user: { email: "", password: "password", password_confirmation: "password" } }
      end

      it "Không tạo user mới và báo lỗi email không được để trống" do
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
        
        expect(response).to have_http_status(200)
        user_in_controller = controller.instance_variable_get(:@user)
        expect(user_in_controller.errors[:email]).to include("không được để trống")
      end
    end
  end
end