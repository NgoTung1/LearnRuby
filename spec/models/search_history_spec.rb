require 'rails_helper'

RSpec.describe SearchHistory, type: :model do
  let(:user) { User.create(email: 'test@example.com', password: 'password123') }

  describe 'associations' do
    it 'Thuộc về usser' do
      assoc = SearchHistory.reflect_on_association(:user)
      expect(assoc.macro).to eq :belongs_to
    end
  end

  describe 'validations' do
    it 'Thành phố và user hợp lệ' do
      history = SearchHistory.new(user: user, city_name: 'Hà Nội')
      expect(history).to be_valid
    end

    it 'Thành phố không hợp lệ' do
      history = SearchHistory.new(user: user, city_name: nil)
      expect(history).not_to be_valid
      expect(history.errors[:city_name]).to include("can't be blank")
    end
  end
end
