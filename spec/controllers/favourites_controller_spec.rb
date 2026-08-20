require 'rails_helper'

RSpec.describe FavouritesController, type: :controller do
  let(:user) { User.create(email: 'test@example.com', password: 'password123', is_verified: true) }

  describe 'GET #index' do
    context 'Khi người dùng đăng nhập' do
      before do
        cookies.encrypted[:user_id] = user.id
        user.favorites.create!(city_name: 'Hà Nội')
        allow(WeatherApiService).to receive(:fetch_cached).with('Hà Nội').and_return({
          success: true,
          data: { 'name' => 'Hà Nội', 'main' => { 'temp' => 30 } }
        })
      end

      it 'Trả về kết quả HTTP thành công' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'Khi người dùng là khách' do
      it 'Chuyển hướng sang trang đăng nhập' do
        get :index
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe 'POST #create' do
    context 'Khi người dùng đăng nhập' do
      before { cookies.encrypted[:user_id] = user.id }

      it 'Tạo thành phố yêu thích mới và trả về json response' do
        post :create, params: { city_name: 'Đà Nẵng' }, format: :json

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['action']).to eq('created')
        expect(user.favorites.find_by(city_name: 'Đà Nẵng')).not_to be_nil
      end
    end

    context 'KHi người dùng là khác' do
      it 'Báo kết quả chưa đăng nhập và trả về json là false' do
        post :create, params: { city_name: 'Đà Nẵng' }, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:fav) { user.favorites.create!(city_name: 'Hà Nội') }

    context 'Khi người dùng đã đăng nhập' do
      before { cookies.encrypted[:user_id] = user.id }

      it 'Hủy thành phố yêu thích và trả về json response' do
        delete :destroy, params: { id: fav.id }, format: :json

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['action']).to eq('destroyed')
        expect(user.favorites.find_by(id: fav.id)).to be_nil
      end

      it 'Trường hợp ở trang favorite: Hủy thành phố yêu thích và load lại trang' do
        delete :destroy, params: { id: fav.id }, format: :html

        expect(response).to redirect_to(favorites_path)
        expect(flash[:notice]).to eq('Đã xóa khỏi danh sách yêu thích.')
      end
    end
  end
end
