class WeathersController < ApplicationController
    def index
        city = (params[:city] || "").strip.squeeze(" ")
        lat = params[:lat] || ""
        lon = params[:lon] || ""
        
        if city.present?
            result = WeatherApiService.new(city).call
            if result[:success]
                @climate = result[:current]
                @hourly = result[:hourly]
                @forecast = result[:forecast]
                SearchHistoryService.record_search(current_user, @climate['name']) if current_user && current_user.is_verified?
            else
                @climate = nil
                @error = result[:error]
            end
            
        elsif lat.present? && lon.present?
            result = WeatherApiService.location_call(lat, lon)
            if result[:success]
                @climate = result[:current]
                @hourly = result[:hourly]
                @forecast = result[:forecast]
                SearchHistoryService.record_search(current_user, @climate['name']) if current_user && current_user.is_verified?
            else
                @climate = nil
                @error = result[:error]
            end
        end
    
        if logged_in?
            recent_records  = SearchHistoryService.recent_searches(current_user, limit: 3)
            @side_histories = recent_records.map do |record|
                response = WeatherApiService.fetch_cached(record.city_name)
                {
                    city: record.city_name,
                    temp: response[:success] ? "#{response[:current]['main']['temp'].round}°C" : "--"
                }
            end
        end
    end
end