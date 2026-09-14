class ChatbotsController < ApplicationController
  def chat
    message = params[:message].to_s.strip
    current_city = params[:current_city].to_s.strip.presence

    if message.blank?
      render json: { success: false, reply: "Vui lòng nhập câu hỏi!" } and return
    end

    if message.length > 500
      render json: { success: false, reply: "Câu hỏi quá dài, vui lòng rút gọn lại!" } and return
    end

    result = ChatbotRagService.new(message, current_city: current_city).call

    render json: {
      success: result[:success],
      reply: result[:reply],
      city: result[:city]
    }
  end

  def analyze_outfit
    image = params[:image]
    current_city = params[:current_city].to_s.strip.presence

    if image.blank?
      render json: { success: false, reply: "Vui lòng chọn một bức ảnh!" } and return
    end

    unless image.content_type&.start_with?("image/")
      render json: { success: false, reply: "File không hợp lệ! Vui lòng chọn file ảnh." } and return
    end

    if image.size > 10.megabytes
      render json: { success: false, reply: "Ảnh quá lớn! Vui lòng chọn ảnh dưới 10MB." } and return
    end

    result = OutfitAnalysisService.new(image, current_city: current_city).call

    render json: {
      success: result[:success],
      reply: result[:reply],
      detected_items: result[:detected_items] || [],
      annotated_image: result[:annotated_image],
      city: result[:city]
    }
  end
end