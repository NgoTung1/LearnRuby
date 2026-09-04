require 'rails_helper'

RSpec.describe ChatbotRagService do
  let(:gemini_service_mock) { instance_double(GeminiService) }
  let(:weather_data) do
    {
      success: true,
      current: {
        'main' => { 'temp' => 30, 'feels_like' => 32, 'humidity' => 70 },
        'weather' => [{ 'description' => 'Mây rải rác' }],
        'wind' => { 'speed' => 3 },
        'visibility' => 10000
      },
      hourly: [
        { 'dt_txt' => '2026-09-04 15:00:00', 'main' => { 'temp' => 31 }, 'weather' => [{ 'description' => 'Nắng' }] }
      ],
      forecast: [
        { 'dt_txt' => '2026-09-05 12:00:00', 'main' => { 'temp_min' => 25, 'temp_max' => 32 }, 'weather' => [{ 'description' => 'Mưa' }] }
      ]
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
          instance_of(String), 
          user_message
        ).and_return({ success: false, error: 'API Error' })
      end

      it 'trả về lỗi với thông báo phù hợp' do
        result = service.call
        
        expect(result[:success]).to eq(false)
        expect(result[:reply]).to include('Xin lỗi, tôi đang gặp sự cố')
      end
    end
  end
end
