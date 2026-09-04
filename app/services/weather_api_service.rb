require 'json'
require 'net/http'

class WeatherApiService
    # Dùng API forecast để lấy cả hiện tại lẫn dự báo
    URL = "https://api.openweathermap.org/data/2.5/forecast"

    def initialize(city_name)
        @city_name = city_name
        @api_key = ENV['WEATHER_API']
    end

    def call
        return {success: false, error: nil} if @city_name.blank?
        
        # Xử lý tiếng Việt
        search_query = @city_name.to_s.unicode_normalize(:nfd).gsub(/[\u0300-\u036f]/, "").gsub(/đ/, "d").gsub(/Đ/, "D").strip
        
        uri = URI("#{URL}?q=#{URI.encode_www_form_component(search_query)}&appid=#{@api_key}&units=metric&lang=vi")
        response = Net::HTTP.get_response(uri)
        
        if response.is_a?(Net::HTTPSuccess) 
            data = JSON.parse(response.body)
            format_forecast_data(data)
        else
            { success: false, error: "Không tìm thấy thành phố '#{@city_name}'" }
        end
    rescue StandardError => e
        Rails.logger.error "====== LỖI API: #{e.message} ======"
        { success: false, error: "Lỗi kết nối mạng: #{e.message}" }
    end

    def self.location_call(lat, lon)
        return {success: false, error: "Thiếu tọa độ"} if lat.blank? || lon.blank?
        api_key = ENV['WEATHER_API']
        
        uri = URI("#{URL}?lat=#{lat}&lon=#{lon}&appid=#{api_key}&units=metric&lang=vi")
        response = Net::HTTP.get_response(uri)
        
        if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            new("").format_forecast_data(data)
        else
            { success: false, error: "Lỗi không kết nối được API (#{response.code})" }
        end
    rescue StandardError => e
        { success: false, error: "Lỗi kết nối mạng: #{e.message}" }
    end

    def self.fetch_cached(city_name)
        return {success: false, error: nil} if city_name.blank?
        clean_key = city_name.to_s.strip.downcase.parameterize
        cached_key = "v3/weather/#{clean_key}" # Đổi version cache vì data format thay đổi

        cached_data = Rails.cache.read(cached_key)
        return cached_data if cached_data.present?

        result = new(city_name).call

        if result[:success]
            Rails.cache.write(cached_key, result, expires_in: 15.minutes)
        end
        result
    end

    def format_forecast_data(data)
        # Hiện tại
        current_weather = data["list"].first
        current_weather["name"] = data["city"]["name"]
        current_weather["sys"] = { "country" => data["city"]["country"] }
        
        # 24 giờ tới (8 mốc thời gian)
        hourly_forecast = data["list"].take(8)
        
        # Nhóm dữ liệu theo ngày để tính Nhiệt độ Cao nhất / Thấp nhất
        today_date = current_weather["dt_txt"].split(' ')[0]
        grouped_by_day = data["list"].group_by { |item| item["dt_txt"].split(' ')[0] }
        
        # Bỏ qua ngày hôm nay trong danh sách 5 ngày tới
        grouped_by_day.delete(today_date)
        
        daily_forecast = grouped_by_day.take(5).map do |date, items|
            min_temp = items.map { |i| i["main"]["temp_min"] }.min
            max_temp = items.map { |i| i["main"]["temp_max"] }.max
            
            # Lấy mốc 12:00 trưa làm đại diện cho thời tiết và icon
            mid_day = items.find { |i| i["dt_txt"].include?("12:00:00") } || items.first
            
            {
                "dt_txt" => date,
                "main" => {
                    "temp_min" => min_temp,
                    "temp_max" => max_temp,
                },
                "weather" => mid_day["weather"]
            }
        end
        
        {
            success: true,
            current: current_weather,
            hourly: hourly_forecast,
            forecast: daily_forecast
        }
    end
end
