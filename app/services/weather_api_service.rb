require 'json'
require 'net/http'

class WeatherApiService
    URL = "https://api.openweathermap.org/data/2.5/weather"
    BULK_URL = "https://api.openweathermap.org/data/2.5/find?lat=16.1667&lon=107.8333&cnt=10"

    def initialize(city_name)
        @city_name = city_name
        @api_key = ENV['WEATHER_API']
    end

    def call
        return {success: false, error: nil} if @city_name.blank?
        uri = URI("#{URL}?q=#{URI.encode_www_form_component(@city_name)}&appid=#{@api_key}&units=metric&lang=vi")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess) 
            {   success: true,
                data: JSON.parse(response.body)
            }
        else
            {
                success: false,
                error: "Không tìm thấy thành phố '#{@city_name}'"
            }
        end
        rescue StandardError => e
            {success: false, error: "Không có kết nối mạng"}
    end

    def self.fetch_cached(city_name)
        return {success: false, error: nil} if city_name.blank?
        clean_key = city_name.to_s.strip.downcase.parameterize
        cached_key = "v1/weather/#{clean_key}"

        cached_data = Rails.cache.read(cached_key)
        return {success: true, data: cached_data} if cached_data.present?

        result = new(city_name).call

        if result[:success]
            Rails.cache.write(cached_key, result[:data], expires_in: 15.minutes)
        end

        result
    end

    def self.location_call(lat, lon)
        return {success: false, error: "Thiếu tọa độ"} if lat.blank? || lon.blank?
        api_key = ENV['WEATHER_API']
        uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{lat}&lon=#{lon}&appid=#{api_key}&units=metric&lang=vi")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
            {
                success: true,
                data: JSON.parse(response.body)
            }
        else
            {
                success: false,
                error: "Lỗi không kết nối được API (#{response.code})"
            }
        end
    rescue StandardError => e
        { success: false, error: "Lỗi kết nối mạng: #{e.message}" }
    end

    def multiple_call
        uri = URI("#{BULK_URL}")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess) 
            {
                success: true,
                data: JSON.parse(response.body)
            }
        else 
            {
                success: false,
                error: "Lỗi không thể hiển thị"
            }
        end
    end
end
