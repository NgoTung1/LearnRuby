require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:password) {"password"}
  let(:verified_user) {User.create!(email: "abc@gmail.com", password: password, is_verified: true)}
  let(:unverified_user) {User.create!(email: "bcd@gmail.com", password: password, is_verified: false)}
  describe "Kiểm tra hiển thị giao diện" do
    it "Trả về giao diện đăng nhập thành công" do
      get :new
      expect(response).to be_successful
    end
  end

  describe "Kiểm tra đăng nhập" do
    context "Nếu sai email/ mật khẩu" do
      it "Trả về message báo lỗi" do
        post :save, params: {email: "test1@gmail.com", password: password}
        expect(flash.now[:alert]).to eq("Tài khoản hoặc mật khẩu không chính xác")
        expect(response).to have_http_status(200)
      end
    end
    
    context "Nếu đăng nhập đúng nhưng chưa xác thực" do
      it "Chuyển hướng sang trang xác thực otp" do
        post :save, params: {email: unverified_user.email,password: password}
        expect(response).to redirect_to(otp_path)
      end
    end

    context "Nếu đăng nhập thành công và đã xác thực" do
      before do
        post :save, params: {email: verified_user.email,password: verified_user.password}
      end
      it "Tạo cookies cho phiên đăng nhập" do
        expect(cookies.encrypted[:user_id]).to eq(verified_user.id)
      end
      it "Thông báo đăng nhập thành công và Chuyển sang trang chủ" do
        expect(flash[:notice]).to eq("Đăng nhập thành công")
        expect(response).to redirect_to(root_path)
      end
    end
  end
    describe "Trường hợp bấm đăng xuất" do
      before do
        cookies.encrypted[:user_id] = verified_user.id
      end

      it "Xóa cookies và chuyển về trang chủ" do
        delete :destroy
        
        expect(response.cookies['user_id']).to be_nil
        expect(flash[:notice]).to eq("Đăng xuất thành công")
        expect(response).to redirect_to(root_path)
      end
    end
  describe 'GET /auth/google_oauth2/callback' do
    context 'khi đăng nhập Google thành công' do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: '987654321',
          info: { email: 'user@gmail.com' }
        })
        request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:google_oauth2]
      end
      it 'lưu cookie user_id và chuyển hướng tới root_path' do
        get :google_login, params: { provider: 'google-oauth2'}
        
        user = User.find_by(email: 'user@gmail.com')
        expect(cookies.encrypted[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
      end
    end
    context 'khi đăng nhập thất bại' do
      before do
        request.env['omniauth.auth'] = nil
      end
      it 'chuyển hướng về trang login' do
        get :google_login, params: {provider: 'google_oauth2'}
        expect(response).to redirect_to(login_path)
      end
    end
  end
end    


