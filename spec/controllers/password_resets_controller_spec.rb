require 'rails_helper'

RSpec.describe PasswordResetsController, type: :controller do
  let!(:user) { User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123", is_verified: true) }

  describe "GET #new" do
    it "hiển thị form quên mật khẩu" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "khi email tồn tại" do
      it "tạo reset token và gửi email" do
        expect {
          post :create, params: { email: user.email }
        }.to have_enqueued_mail(UserMailer, :reset_password_email)

        user.reload
        expect(user.reset_password_token).to be_present
        expect(user.reset_password_sent_at).to be_present
      end

      it "redirect về trang login với thông báo" do
        post :create, params: { email: user.email }
        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("Nếu email tồn tại")
      end
    end

    context "khi email không tồn tại" do
      it "vẫn redirect với cùng thông báo (bảo mật)" do
        post :create, params: { email: "nonexistent@example.com" }
        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("Nếu email tồn tại")
      end
    end
  end

  describe "GET #edit" do
    context "khi token hợp lệ" do
      before { user.generate_reset_password_token! }

      it "hiển thị form đặt lại mật khẩu" do
        get :edit, params: { token: user.reset_password_token }
        expect(response).to have_http_status(:success)
      end
    end

    context "khi token hết hạn" do
      before do
        user.generate_reset_password_token!
        user.update_column(:reset_password_sent_at, 11.minutes.ago)
      end

      it "redirect về trang quên mật khẩu" do
        get :edit, params: { token: user.reset_password_token }
        expect(response).to redirect_to(forgot_password_path)
        expect(flash[:alert]).to include("hết hạn")
      end
    end

    context "khi token không tồn tại" do
      it "redirect về trang quên mật khẩu" do
        get :edit, params: { token: "invalid_token" }
        expect(response).to redirect_to(forgot_password_path)
        expect(flash[:alert]).to include("không hợp lệ")
      end
    end
  end

  describe "POST #update" do
    before { user.generate_reset_password_token! }

    context "khi mật khẩu hợp lệ" do
      it "đặt lại mật khẩu thành công" do
        post :update, params: {
          token: user.reset_password_token,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include("thành công")

        user.reload
        expect(user.authenticate("newpassword123")).to be_truthy
        expect(user.reset_password_token).to be_nil
      end
    end

    context "khi mật khẩu không khớp" do
      it "hiện lỗi" do
        post :update, params: {
          token: user.reset_password_token,
          password: "newpassword123",
          password_confirmation: "differentpassword"
        }

        expect(response).to render_template(:edit)
        expect(flash[:alert]).to include("không trùng khớp")
      end
    end

    context "khi mật khẩu quá ngắn" do
      it "hiện lỗi" do
        post :update, params: {
          token: user.reset_password_token,
          password: "123",
          password_confirmation: "123"
        }

        expect(response).to render_template(:edit)
        expect(flash[:alert]).to include("ít nhất 6")
      end
    end

    context "khi token hết hạn" do
      before { user.update_column(:reset_password_sent_at, 11.minutes.ago) }

      it "redirect về trang quên mật khẩu" do
        post :update, params: {
          token: user.reset_password_token,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }

        expect(response).to redirect_to(forgot_password_path)
        expect(flash[:alert]).to include("hết hạn")
      end
    end
  end
end
