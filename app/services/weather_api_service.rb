require 'json'
require 'net/http'
class WeatherApiService
    url = "https://api.openweathermap.org/data/2.5/weather"
    bulk_url = "api.openweathermap.org/data/2.5//find?lat=16.1667&lon=107.8333&cnt=10"

    def initialize(city_name)
        @city_name = city_name
        @api_key = ENV['WEATHER_API']
    end
    def call
     uri = URI("#{url}?q=#{URI.encode_www_from_component(@city_name)}&appid=#{@api_key}&units=metric&lang=vi")
     response = Net::HTTP.get_response(uri)
     if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
     else
        {
            success: false,
            error: "Không tìm thấy thành phố '#{@city_name}'"
        }
    end
end
    def multiple_call
        uri = URI("#{bulk_url}")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.data)
        else 
            {
                success: false,
                error: "Lỗi không thể hiển thị"
            }
end
