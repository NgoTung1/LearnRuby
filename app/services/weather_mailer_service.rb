class WeatherMailerService 
  def self.check_and_send_mail!
    User.includes(:favorites).find_each do |user|
      next if user.favorites.empty?
      user_alerts = [] 
      user.favorites.each do |fav|
        result = WeatherApiService.fetch_cached(fav.city_name)
        next unless result[:success]

        data = result[:data]
        city_name = data['name']
        temp = data.dig('main', 'temp')
        wind_speed = data.dig('wind', 'speed')
        weather_main = data.dig('weather', 0, 'main')
        weather_desc = data.dig('weather', 0, 'description')

        reasons = []

        if %w[Thunderstorm Squall Tornado Snow].include?(weather_main)
          reasons << "Thời tiết cực đoan: #{weather_desc}"
        elsif weather_main == 'Rain' && data.dig('rain', '1h').to_f > 10.0
          reasons << "Mưa rất lớn (#{data.dig('rain', '1h')} mm/h)"
        end

        if temp.to_f > 38.0
          reasons << "Nhiệt độ quá cao (#{temp}°C - Nguy cơ sốc nhiệt)"
        elsif temp.to_f < 5.0
          reasons << "Nhiệt độ quá thấp (#{temp}°C - Rất lạnh)"
        end

        if wind_speed.to_f > 15.0
          reasons << "Gió rất mạnh (#{wind_speed} m/s)"
        end

        if reasons.any?
          user_alerts << {
            city: city_name,
            condition: weather_desc.capitalize,
            temp: temp,
            wind: wind_speed,
            advice: reasons.join(';')
          }
        end
      end
      if user_alerts.any?
        WeatherMailerAlert.extreme_weather_alert(user, user_alerts).deliver_now
      end
    end
  end
  def self.daily_digest!
    User.includes(:favorites).find_each do |user|
      next if user.favorites.empty?
      weather_list = []
      user.favorites.each do |fav|
        result = WeatherApiService.fetch_cached(fav.city_name)
        weather_list << result[:data] if result[:success]
      end
      if weather_list.any?
        WeatherMailerAlert.daily_digest(user, weather_list).deliver_now
      end
    end
  end

end