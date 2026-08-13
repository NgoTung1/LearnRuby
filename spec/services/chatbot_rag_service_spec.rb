require 'rails_helper'

RSpec.describe ChatbotRagService do
  let(:gemini_service_mock) { instance_double(GeminiService) }
  let(:weather_data) do
    {
      success: true,
      data: {
        'main' => { 'temp' => 30, 'feels_like' => 32, 'temp_min' => 28, 'temp_max' => 31, 'humidity' => 70, 'pressure' => 1010 },
        'weather' => [{ 'description' => 'Mây rải rác' }],
        'wind' => { 'speed' => 3 },
        'visibility' => 10000
      }
    }
  end

  before do
    allow(GeminiService).to receive(:new).and_return(gemini_service_mock)
    allow(WeatherApiService).to receive(:fetch_cached).and_return(weather_data)
  end

  describe '#call' do
    context 'khi tin nhắn có chứa tên thành phố' do
      let(:user_message) { 'Thời tiết Đà Nẵng thế nào?' }
      let(:service) { described_class.new(user_message, current_city: 'Hà Nội') }

      before do
        allow(gemini_service_mock).to receive(:generate).with(
          "Bạn là hệ thống trích xuất dữ liệu tự động.", 
          instance_of(String)
        ).and_return({ success: true, reply: 'Đà Nẵng' })

        allow(gemini_service_mock).to receive(:generate).with(
          instance_of(String), 
          user_message
        ).and_return({ success: true, reply: 'Thời tiết Đà Nẵng hôm nay có mây rải rác.' })
      end

      it 'sử dụng thành phố được trích xuất từ tin nhắn để lấy thời tiết' do
        expect(WeatherApiService).to receive(:fetch_cached).with('Đà Nẵng')
        
        result = service.call
        
        expect(result[:success]).to eq(true)
        expect(result[:city]).to eq('Đà Nẵng')
        expect(result[:reply]).to eq('Thời tiết Đà Nẵng hôm nay có mây rải rác.')
      end
    end

    context 'khi tin nhắn KHÔNG chứa tên thành phố' do
      let(:user_message) { 'Hôm nay trời có mưa không?' }
      let(:service) { described_class.new(user_message, current_city: 'Hồ Chí Minh') }

      before do
        allow(gemini_service_mock).to receive(:generate).with(
          "Bạn là hệ thống trích xuất dữ liệu tự động.", 
          instance_of(String)
        ).and_return({ success: true, reply: 'NONE' })

        allow(gemini_service_mock).to receive(:generate).with(
          instance_of(String), 
          user_message
        ).and_return({ success: true, reply: 'Trời Hồ Chí Minh hôm nay không mưa.' })
      end

      it 'sử dụng current_city truyền vào làm mặc định' do
        expect(WeatherApiService).to receive(:fetch_cached).with('Hồ Chí Minh')
        
        result = service.call
        
        expect(result[:success]).to eq(true)
        expect(result[:city]).to eq('Hồ Chí Minh')
        expect(result[:reply]).to eq('Trời Hồ Chí Minh hôm nay không mưa.')
      end
    end

    context 'khi Gemini Service gặp lỗi lúc sinh câu trả lời' do
      let(:user_message) { 'Thời tiết thế nào?' }
      let(:service) { described_class.new(user_message, current_city: 'Hà Nội') }

      before do
        allow(gemini_service_mock).to receive(:generate).with(
          "Bạn là hệ thống trích xuất dữ liệu tự động.", 
          instance_of(String)
        ).and_return({ success: true, reply: 'NONE' })

        allow(gemini_service_mock).to receive(:generate).with(
          instance_of(String), 
          user_message
        ).and_return({ success: false, error: 'API Error' })
      end

      it 'trả về lỗi với thông báo phù hợp' do
        result = service.call
        
        expect(result[:success]).to eq(false)
        expect(result[:reply]).to include('Xin lỗi, tôi đang gặp sự cố')
        expect(result[:reply]).to include('API Error')
      end
    end
  end
end
