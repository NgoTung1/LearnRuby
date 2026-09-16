require 'rails_helper'

RSpec.describe HistoriesController, type: :controller do
  let(:user) { User.create(email: 'test@example.com', password: 'password123', is_verified: true) }

  describe 'GET #index' do
    context 'Khi người dùng đăng nhập' do
      before do
        cookies.encrypted[:user_id] = user.id
        SearchHistory.create!(user: user, city_name: 'Hà Nội')
        allow(WeatherApiService).to receive(:fetch_cached).with('Hà Nội').and_return({
          success: true,
          data: { 'main' => { 'temp' => 32 } }
        })
      end

      it 'Trả về trạng thái HTTP success' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'Khi người dùng chưa đăng nhập' do
      it 'Chuyển hướng về trang chủ' do
        get :index
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
