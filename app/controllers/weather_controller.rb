class WeatherController < ApplicationController
    def index
        city = params[:city] || ""
        weather = WeatherApiService.new(city)
        result = weather.call
        if result[:success]
            @climate = result[:data]
        else
            @climate = nil
            @error = result[:error]
        end
    end
end