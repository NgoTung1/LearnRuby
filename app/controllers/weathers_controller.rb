class WeathersController < ApplicationController
    def index
        city = (params[:city] || "").strip.squeeze(" ")
        lat = params[:lat] || ""
        lon = params[:lon] || ""
        
        if city.present?
            result = WeatherApiService.new(city).call
            if result[:success]
                @climate = result[:current] || result[:data]
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
                @climate = result[:current] || result[:data]
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
                temp = if response[:success]
                         current = response[:current] || response[:data]
                         current ? "#{current.dig('main', 'temp')&.round}°C" : "--"
                       else
                         "--"
                       end
                {
                    city: record.city_name,
                    temp: temp
                }
            end
        end

        respond_to do |format|
            format.html
            format.json do
                render json: {
                    success: @climate.present?,
                    error: @error,
                    city: @climate&.dig('name') || city,
                    html: render_to_string(partial: 'weathers/result', formats: [:html]),
                    sidebar_html: (logged_in? && current_user.is_verified?) ? render_to_string(partial: 'weathers/sidebar', formats: [:html]) : nil
                }
            end
        end
    end
end