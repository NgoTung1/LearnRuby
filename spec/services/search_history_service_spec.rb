require 'rails_helper'

RSpec.describe SearchHistoryService do
  let(:user) { User.create(email: 'test@example.com', password: 'password123') }

  describe '.record_search' do
    it 'Trả về nil nếu đang là khách' do
      expect(SearchHistoryService.record_search(nil, 'Hà Nội')).to be_nil
    end

    it 'Trả về nil nếu chưa nhập gì' do
      expect(SearchHistoryService.record_search(user, '')).to be_nil
    end

    it 'Tạo bản ghi lịch sử tìm kiếm' do
      expect {
        SearchHistoryService.record_search(user, 'Hà Nội')
      }.to change(SearchHistory, :count).by(1)

      expect(user.search_histories.last.city_name).to eq('Hà Nội')
    end

    it 'Cập nhật lại thời gian khi tìm kiếm một thành phố đã có trong lịch sử tìm kiếm' do
      history = SearchHistory.create!(user: user, city_name: 'Hà Nội', updated_at: 1.day.ago)

      expect {
        SearchHistoryService.record_search(user, 'Hà Nội')
      }.not_to change(SearchHistory, :count)

      history.reload
      expect(history.updated_at).to be_within(5.seconds).of(Time.current)
    end

    it 'Xóa bản ghi cũ nhất khi tìm kiếm thành phố thứ 11' do
      11.times do |i|
        SearchHistoryService.record_search(user, "City #{i + 1}")
      end

      expect(user.search_histories.count).to eq(10)
      expect(user.search_histories.pluck(:city_name)).not_to include('City 1')
      expect(user.search_histories.pluck(:city_name)).to include('City 11')
    end
  end

  describe '.recent_searches' do
    it 'Trả về mảng rỗng nếu user là nil' do
      expect(SearchHistoryService.recent_searches(nil)).to eq([])
    end

    it 'Trả về danh sách tìm kiếm theo thứ tự giảm dần' do
      SearchHistory.create!(user: user, city_name: 'Hà Nội', updated_at: 2.hours.ago)
      SearchHistory.create!(user: user, city_name: 'Đà Nẵng', updated_at: 1.hour.ago)

      results = SearchHistoryService.recent_searches(user, limit: 10)
      expect(results.map(&:city_name)).to eq(['Đà Nẵng', 'Hà Nội'])
    end

    it 'Kiểm tra giới hạn trong params' do
      5.times do |i|
        SearchHistoryService.record_search(user, "City #{i + 1}")
      end

      results = SearchHistoryService.recent_searches(user, limit: 3)
      expect(results.count).to eq(3)
    end
  end
end
