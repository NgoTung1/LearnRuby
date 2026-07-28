require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: "Hello RSpec"
    end
  end

  describe "Kiểm tra trạng thái đăng nhập" do
    let(:user) { User.create!(email: "test_rspec@gmail.com", password: "password123") }

    context "khi có cookie hợp lệ" do
      before do
        request.cookie_jar.encrypted[:user_id] = user.id
        get :index 
      end

      it "hàm current_user trả về đúng user" do
        expect(controller.send(:current_user)).to eq(user)
      end

      it "hàm logged_in? trả về true" do
        expect(controller.send(:logged_in?)).to be_truthy
      end
    end

    context "khi chưa đăng nhập (không có cookie)" do
      before do
        request.cookie_jar.encrypted[:user_id] = nil
        get :index
      end

      it "hàm current_user trả về nil" do
        expect(controller.send(:current_user)).to be_nil
      end

      it "hàm logged_in? trả về false" do
        expect(controller.send(:logged_in?)).to be_falsey
      end
    end
  end
end