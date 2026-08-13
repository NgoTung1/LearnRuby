class ChatbotRagService
  def initialize(user_message, current_city: nil)
    @user_message = user_message
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
      { success: false, reply: "Xin lỗi, tôi đang gặp sự cố. Vui lòng thử lại sau! (#{result[:error]})" }
    end
  end

  private

  def extract_city_from_message
    extraction_prompt = <<~PROMPT
      Nhiệm vụ của bạn là trích xuất TÊN THÀNH PHỐ hoặc TỈNH được nhắc đến trong câu người dùng.
      QUY TẮC:
      1. CHỈ in ra tên thành phố, KHÔNG có bất kỳ ký tự, dấu câu hay lời giải thích nào khác.
      2. Tên thành phố có thể là tiếng Việt hoặc tiếng Anh (ví dụ: Hokkaido, Tokyo, Paris, Đà Nẵng).
      3. Nếu trong câu KHÔNG CÓ thành phố nào được nhắc đến, CHỈ in ra đúng chữ "NONE".
      
      Câu của người dùng: "#{@user_message}"
    PROMPT

    gemini = GeminiService.new
    result = gemini.generate("Bạn là hệ thống trích xuất dữ liệu tự động.", extraction_prompt)

    if result[:success]
      extracted = result[:reply].to_s.strip
      return nil if extracted.upcase == "NONE" || extracted.blank?
      return extracted
    end

    nil
  end

  def build_system_prompt(city, weather_result)
    if weather_result[:success] && weather_result[:data].present?
      data = weather_result[:data]
      main = data['main'] || {}
      weather_info = data['weather']&.first || {}
      wind = data['wind'] || {}

      weather_context = <<~CONTEXT
        DỮ LIỆU THỜI TIẾT THỰC TẾ TẠI #{city.upcase}:
        - Nhiệt độ hiện tại: #{main['temp']}°C (Cảm giác như: #{main['feels_like']}°C)
        - Nhiệt độ thấp nhất: #{main['temp_min']}°C / Cao nhất: #{main['temp_max']}°C
        - Tình trạng: #{weather_info['description']}
        - Độ ẩm: #{main['humidity']}%
        - Tốc độ gió: #{wind['speed']} m/s
        - Áp suất: #{main['pressure']} hPa
        - Tầm nhìn: #{data['visibility']} mét
      CONTEXT
    else
      weather_context = "KHÔNG CÓ DỮ LIỆU THỜI TIẾT cho #{city}. Hãy thông báo cho người dùng rằng bạn không thể lấy được dữ liệu thời tiết hiện tại."
    end

    <<~SYSTEM_PROMPT
      Bạn là "Weather Bot" - Trợ lý thời tiết thông minh của ứng dụng Weather on Rails.

      QUY TẮC BẮT BUỘC:
      1. CHỈ trả lời dựa trên dữ liệu thời tiết thực tế được cung cấp bên dưới. KHÔNG BAO GIỜ bịa ra số liệu.
      2. Trả lời bằng Tiếng Việt, thân thiện, ngắn gọn (tối đa 3-4 câu).
      3. Đưa ra lời khuyên thiết thực: nên mặc gì, mang theo gì (ô, kính râm...), có nên ra ngoài không.
      4. Sử dụng emoji phù hợp để sinh động hơn.
      5. Nếu người dùng hỏi ngoài chủ đề thời tiết, hãy lịch sự từ chối và gợi ý họ hỏi về thời tiết.

      #{weather_context}
    SYSTEM_PROMPT
  end
end
