require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'Liên kết thông tin từ đăng nhập bằng Google vào database' do
    let(:auth) do
      OmniAuth::AuthHash.new({
        provider: 'google-oauth2',
        uid: '123456789',
        info: {
          email: 'test@gmail.com'
        }
      })
    end

    context 'khi email chưa tồn tại trong DB' do
      it 'tạo mới user thành công với is_verified = true' do
        expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.email).to eq('test@gmail.com')
        expect(user.uid).to eq('123456789')
        expect(user.is_verified).to be true
      end
    end
    context 'khi email đã tồn tại trong DB' do
      let!(:existing_user) { User.create!(email: 'test@gmail.com', password: 'password123', password_confirmation: 'password123') }
      it 'cập nhật uid và is_verified mà không tạo thêm user mới' do
        expect { User.from_omniauth(auth) }.not_to change(User, :count)
        existing_user.reload
        expect(existing_user.uid).to eq('123456789')
        expect(existing_user.is_verified).to be true
      end
    end
  end
end
