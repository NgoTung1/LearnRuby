require 'net/http'
require 'json'

class GeminiService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"

  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
  end

  def generate(system_prompt, user_message)
    uri = URI("#{API_URL}?key=#{@api_key}")

    body = {
      model: "gemini-3.6-flash",
      system_instruction: system_prompt,
      input: user_message,
      generation_config: {
        max_output_tokens: 1024
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      text = extract_text_from_response(data)
      { success: true, reply: text || "Xin lỗi, tôi không thể trả lời lúc này." }
    else
      error_data = JSON.parse(response.body) rescue {}
      error_msg = error_data.dig("error", "message") || "Lỗi API (#{response.code})"
      { success: false, error: error_msg }
    end

  rescue Net::ReadTimeout
    { success: false, error: "Gemini API phản hồi quá lâu, vui lòng thử lại." }
  rescue StandardError => e
    { success: false, error: "Lỗi kết nối: #{e.message}" }
  end

  private

  def extract_text_from_response(data)
    return data["output_text"] if data["output_text"].to_s.strip.present?

    (data["steps"] || []).each do |step|
      next unless step["type"] == "model_output"
      text = step.dig("content", 0, "text")
      return text if text.to_s.strip.present?
    end

    nil
  rescue StandardError
    nil
  end
end