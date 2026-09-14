require 'net/http'
require 'json'
require 'uri'

class ClothingDetectionService
  AI_API_URL = ENV.fetch('AI_API_URL', 'http://ai_api:8000')

  def initialize(image_file)
    @image_file = image_file
  end

  def call
    uri = URI("#{AI_API_URL}/detect")

    boundary = "----RubyFormBoundary#{SecureRandom.hex(8)}"
    body = build_multipart_body(boundary)

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      {
        success: data['success'],
        detections: data['detections'] || [],
        annotated_image: data['annotated_image'],
        summary: data['summary'] || '',
        total: data['total'] || 0,
        pipeline: data['pipeline']
      }
    else
      error_msg = begin
        JSON.parse(response.body).dig('detail') || "Lỗi AI API (#{response.code})"
      rescue
        "Lỗi AI API (#{response.code})"
      end
      { success: false, error: error_msg, detections: [] }
    end

  rescue Net::ReadTimeout
    { success: false, error: "AI Service phản hồi quá lâu, vui lòng thử lại.", detections: [] }
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    { success: false, error: "Không thể kết nối tới AI Service.", detections: [] }
  rescue StandardError => e
    { success: false, error: "Lỗi kết nối AI: #{e.message}", detections: [] }
  end

  private

  def build_multipart_body(boundary)
    file_content = if @image_file.respond_to?(:read)
                     @image_file.read
                   elsif @image_file.respond_to?(:tempfile)
                     File.binread(@image_file.tempfile.path)
                   else
                     File.binread(@image_file.to_s)
                   end

    @image_file.rewind if @image_file.respond_to?(:rewind)

    filename = if @image_file.respond_to?(:original_filename)
                 @image_file.original_filename
               else
                 "upload.jpg"
               end

    content_type = if @image_file.respond_to?(:content_type)
                     @image_file.content_type
                   else
                     "image/jpeg"
                   end

    body = ""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n"
    body << "\r\n"
    body << file_content
    body << "\r\n"
    body << "--#{boundary}--\r\n"
    body
  end
end
