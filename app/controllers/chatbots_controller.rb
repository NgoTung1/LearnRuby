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
end