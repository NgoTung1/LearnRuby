class WeathersController < ApplicationController
    def index
        city = params[:city] || ""
        lat = params[:lat] || ""
        lon = params[:lon] || ""
        if city.present?
            weather = WeatherApiService.new(city)
            result = weather.call
            if result[:success]
                @climate = result[:data]
                SearchHistoryService.record_search(current_user, @climate['name']) if current_user && current_user.is_verified?
            else
                @climate = nil
                @error = result[:error]
            end
        elsif lat.present? && lon.present?
            weather = WeatherApiService.location_call(lat, lon)
            if weather[:success]
                @climate = weather[:data]
                SearchHistoryService.record_search(current_user, @climate['name']) if current_user && current_user.is_verified?
            else
                @climate = nil
                @error = weather[:error]
            end
        end
    
        if logged_in?
            recent_records  = SearchHistoryService.recent_searches(current_user, limit: 3)
            @side_histories = recent_records.map do |record|
                response = WeatherApiService.fetch_cached(record.city_name)
                {
                    city: record.city_name,
                    temp: response[:success] ? "#{response[:data]['main']['temp'].round}°C" : "--"
                }
            end
        end
    end
end