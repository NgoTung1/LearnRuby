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
