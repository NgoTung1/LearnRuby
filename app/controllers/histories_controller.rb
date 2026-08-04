class HistoriesController < ApplicationController
  def index
    unless logged_in?
      redirect_to login_path, alert: "Bạn không thể sử dụng tính năng này khi chưa đăng nhập"
      return
    end

    records = SearchHistoryService.recent_searches(current_user)
    @histories = records.map do |record|
      response = WeatherApiService.fetch_cached(record.city_name)
      {
        id: record.id,
        city_name: record.city_name,
        updated_at: record.updated_at,
        weather: response[:success] ? response[:data] : nil
      }
    end
  end
end
