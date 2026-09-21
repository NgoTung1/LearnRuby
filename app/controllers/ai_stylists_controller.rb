class AiStylistsController < ApplicationController
  def index
  end

  def analyze
    image = params[:image]
    city = params[:city] || "Hanoi"

    if image.present?
      service = OutfitAnalysisService.new(image, current_city: city)
      result = service.call

      if result[:success]
        render json: {
          success: true,
          reply: result[:reply],
          detected_items: result[:detected_items],
          annotated_image: result[:annotated_image]
        }
      else
        render json: { success: false, error: result[:reply] }
      end
    else
      render json: { success: false, error: "Vui lòng chọn một bức ảnh!" }
    end
  rescue StandardError => e
    Rails.logger.error "Lỗi AI Stylist: #{e.message}"
    render json: { success: false, error: "Đã xảy ra lỗi hệ thống: #{e.message}" }
  end
end
