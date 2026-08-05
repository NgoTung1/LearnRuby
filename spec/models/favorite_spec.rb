require 'rails_helper'

RSpec.describe Favorite, type: :model do
  let(:user) { User.create(email: 'test@example.com', password: 'password123') }

  describe 'associations' do
    it 'thuộc về user' do
      assoc = Favorite.reflect_on_association(:user)
      expect(assoc.macro).to eq :belongs_to
    end
  end

  describe 'validations' do
    it 'Tên thành phố và user hợp lệ' do
      fav = Favorite.new(user: user, city_name: 'Hà Nội')
      expect(fav).to be_valid
    end

    it 'Thành phố không hợp lệ' do
      fav = Favorite.new(user: user, city_name: nil)
      expect(fav).not_to be_valid
      expect(fav.errors[:city_name]).to include("can't be blank")
    end

    it 'Ngăn trùng lặp thành phố' do
      Favorite.create!(user: user, city_name: 'Hà Nội')
      duplicate_fav = Favorite.new(user: user, city_name: 'Hà Nội')

      expect(duplicate_fav).not_to be_valid
      expect(duplicate_fav.errors[:city_name]).to include('Đã có trong danh sách yêu thích')
    end

    it 'Cho phép tồn tại nhiều thành phố nhưng phải khác user_id' do
      user2 = User.create(email: 'user2@example.com', password: 'password123')
      Favorite.create!(user: user, city_name: 'Hà Nội')
      fav2 = Favorite.new(user: user2, city_name: 'Hà Nội')

      expect(fav2).to be_valid
    end
  end
end
