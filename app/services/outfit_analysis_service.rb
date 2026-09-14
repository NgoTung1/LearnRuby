class OutfitAnalysisService
  def initialize(image_file, current_city: nil)
    @image_file = image_file
    @current_city = current_city || "Hanoi"
  end

  def call
    # Bước 1: Gửi ảnh → AI Service (two-stage pipeline)
    detection_result = ClothingDetectionService.new(@image_file).call

    unless detection_result[:success]
      return {
        success: false,
        reply: "Xin lỗi, hệ thống AI đang gặp sự cố: #{detection_result[:error]}",
        detected_items: [],
        annotated_image: nil
      }
    end

    detections = detection_result[:detections]
    annotated_image = detection_result[:annotated_image]

    if detections.empty?
      return {
        success: true,
        reply: "🤔 Mình không nhận diện được trang phục nào trong ảnh. Bạn thử chụp rõ hơn hoặc để quần áo trên nền sáng nhé!",
        detected_items: [],
        annotated_image: annotated_image,
        city: @current_city
      }
    end

    # Bước 2: Lấy dữ liệu thời tiết
    weather_result = WeatherApiService.fetch_cached(@current_city)

    # Bước 3: Build prompt → gọi Gemini
    system_prompt = build_outfit_prompt(detections, weather_result)
    user_prompt = build_user_prompt(detections)

    gemini = GeminiService.new
    result = gemini.generate(system_prompt, user_prompt)

    if result[:success]
      detected_items = detections.map { |d| d['class_vi'] }.uniq
      {
        success: true,
        reply: result[:reply],
        detected_items: detected_items,
        annotated_image: annotated_image,
        city: @current_city,
        pipeline: detection_result[:pipeline]
      }
    else
      {
        success: false,
        reply: "Xin lỗi, mình không thể phân tích lúc này. Vui lòng thử lại! (#{result[:error]})",
        detected_items: [],
        annotated_image: annotated_image
      }
    end
  end

  private

  def build_outfit_prompt(detections, weather_result)
    clothing_list = detections.map do |d|
      conf = d['cls_conf'] || d['det_conf']
      "- #{d['class_vi']} (#{d['class']}, độ tin cậy: #{(conf * 100).round}%, mức giữ ấm: #{d['warmth']})"
    end.join("\n")

    if weather_result[:success] && weather_result[:data].present?
      data = weather_result[:data]
      main = data['main'] || {}
      weather_info = data['weather']&.first || {}
      wind = data['wind'] || {}

      weather_context = <<~CONTEXT
        DỮ LIỆU THỜI TIẾT THỰC TẾ TẠI #{@current_city.upcase}:
        - Nhiệt độ hiện tại: #{main['temp']}°C (Cảm giác như: #{main['feels_like']}°C)
        - Nhiệt độ thấp nhất: #{main['temp_min']}°C / Cao nhất: #{main['temp_max']}°C
        - Tình trạng: #{weather_info['description']}
        - Độ ẩm: #{main['humidity']}%
        - Tốc độ gió: #{wind['speed']} m/s
      CONTEXT
    else
      weather_context = "KHÔNG CÓ DỮ LIỆU THỜI TIẾT cho #{@current_city}. Hãy đưa ra lời khuyên chung."
    end

    <<~SYSTEM_PROMPT
      Bạn là "AI Stylist" - Chuyên gia tư vấn trang phục theo thời tiết của ứng dụng Weather on Rails.

      NHIỆM VỤ: Phân tích trang phục mà hệ thống Computer Vision (YOLOv8 + ResNet50) đã nhận diện,
      và đưa ra lời khuyên dựa trên dữ liệu thời tiết thực tế.

      QUY TẮC BẮT BUỘC:
      1. Trả lời bằng Tiếng Việt, thân thiện, như một người bạn tư vấn thời trang.
      2. Đánh giá mức độ phù hợp (Phù hợp / Hơi nóng / Hơi lạnh / Không phù hợp).
      3. Đưa ra gợi ý cụ thể: nên thêm/bớt gì, mang theo phụ kiện gì.
      4. Ngắn gọn, tối đa 4-5 câu. Sử dụng emoji.
      5. KHÔNG bịa số liệu thời tiết.

      TRANG PHỤC PHÁT HIỆN TỪ ẢNH:
      #{clothing_list}

      #{weather_context}
    SYSTEM_PROMPT
  end

  def build_user_prompt(detections)
    items = detections.map { |d| d['class_vi'] }.uniq.join(", ")
    "Mình đang mặc #{items}. Bộ đồ này có phù hợp với thời tiết hiện tại không?"
  end
end
