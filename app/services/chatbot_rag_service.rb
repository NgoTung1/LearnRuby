class ChatbotRagService
  POPULAR_CITIES = [
    "Hà Nội", "Hanoi", "Hồ Chí Minh", "Sài Gòn", "Saigon", "TPHCM", "TP.HCM",
    "Đà Nẵng", "Danang", "Hải Phòng", "Cần Thơ", "Huế", "Nha Trang", "Đà Lạt",
    "Vũng Tàu", "Quảng Ninh", "Hạ Long", "Thái Nguyên", "Bắc Ninh", "Nam Định", 
    "Thanh Hóa", "Vinh", "Quy Nhơn", "Phan Thiết", "Phú Quốc", "Buôn Ma Thuột",
    "Tokyo", "Seoul", "Bangkok", "Singapore", "Paris", "London", "New York"
  ].freeze

  def initialize(user_message, current_city: nil)
    @user_message = user_message.to_s
    @current_city = current_city  
  end

  def call
    city = extract_city_from_message || @current_city || "Hanoi"
    
    weather_result = WeatherApiService.fetch_cached(city)

    system_prompt = build_system_prompt(city, weather_result)
    gemini = GeminiService.new
    result = gemini.generate(system_prompt, @user_message)

    if result[:success]
      { success: true, reply: result[:reply], city: city }
    else
      Rails.logger.error("[Chatbot Error] #{result[:error]}")
      user_msg = if result[:error].to_s.include?("quota") || result[:error].to_s.include?("RESOURCE_EXHAUSTED")
        "Trợ lý AI đang tạm thời quá tải lượt hỏi, bạn vui lòng đợi khoảng 1 phút rồi thử lại nhé! 😊"
      else
        "Xin lỗi, tôi đang gặp sự cố kết nối. Vui lòng thử lại sau ít phút!"
      end
      { success: false, reply: user_msg }
    end
  end

  private

  def extract_city_from_message
    return nil if @user_message.blank?

    POPULAR_CITIES.each do |city_name|
      if @user_message.downcase.include?(city_name.downcase)
        return city_name
      end
    end

    if match = @user_message.match(/(?:ở|tại|thành phố|tp)\s+([^\?\.,!]+)/i)
      extracted = match[1].to_s.strip.split.take(3).join(" ")
      return extracted if extracted.present?
    end

    nil
  end

  def build_system_prompt(city, weather_result)
    if weather_result[:success] && weather_result[:current].present?
      current = weather_result[:current]
      main = current['main'] || {}
      weather_info = current['weather']&.first || {}
      wind = current['wind'] || {}

      # Gói gọn dự báo 24h (chỉ lấy 4 mốc thời gian để đỡ tốn token)
      hourly_context = weather_result[:hourly].take(4).map do |h|
        "#{Time.parse(h['dt_txt']).strftime('%H:%M')} (#{h['main']['temp'].round}°, #{h['weather'][0]['description']})"
      end.join(" | ")

      # Gói gọn dự báo 5 ngày
      forecast_context = weather_result[:forecast].map do |d|
        "#{Date.parse(d['dt_txt']).strftime('%d/%m')} (#{d['main']['temp_min'].round}-#{d['main']['temp_max'].round}°, #{d['weather'][0]['description']})"
      end.join(" | ")

      weather_context = <<~CONTEXT
        DỮ LIỆU THỜI TIẾT TẠI #{city.upcase}:
        - Hiện tại: #{main['temp'].round}°C (Cảm giác: #{main['feels_like'].round}°C), #{weather_info['description']}
        - Tầm nhìn: #{current['visibility']}m, Gió: #{wind['speed']}m/s, Ẩm: #{main['humidity']}%
        - Vài giờ tới: #{hourly_context}
        - Vài ngày tới: #{forecast_context}
      CONTEXT
    else
      weather_context = "KHÔNG CÓ DỮ LIỆU THỜI TIẾT cho #{city}. Hãy thông báo cho người dùng rằng bạn không thể lấy được dữ liệu thời tiết hiện tại."
    end

    <<~SYSTEM_PROMPT
      Bạn là "Weather Bot" - Trợ lý thời tiết thông minh của ứng dụng Weather on Rails.

      QUY TẮC BẮT BUỘC:
      1. CHỈ trả lời dựa trên dữ liệu thời tiết thực tế được cung cấp bên dưới. KHÔNG BAO GIỜ bịa ra số liệu.
      2. Trả lời bằng Tiếng Việt, thân thiện, tự nhiên và BẮT BUỘC NGẮN GỌN (tối đa 2-3 câu).
      3. Đưa ra lời khuyên thiết thực (ví dụ: mang ô nếu dự báo có mưa, bôi kem chống nắng nếu nắng...).
      4. Bạn biết cả thời tiết hiện tại, vài giờ tới, và vài ngày tới nhờ dữ liệu ở dưới.
      5. Nếu người dùng hỏi ngoài chủ đề thời tiết, hãy lịch sự từ chối và hướng họ về thời tiết.

      #{weather_context}
    SYSTEM_PROMPT
  end
end
