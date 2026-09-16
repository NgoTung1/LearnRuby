require 'rails_helper'

RSpec.describe WeatherApiService do
  let(:api_key) { 'fake_api_key' }
  
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('WEATHER_API').and_return(api_key)
  end

  describe '#call' do
    context 'when city_name is blank' do
      it 'returns success false and error nil' do
        service = WeatherApiService.new('')
        result = service.call
        expect(result[:success]).to be false
        expect(result[:error]).to be_nil
      end
    end

    context 'when API call is successful' do
      let(:city_name) { 'Hồ Chí Minh' }
      let(:mock_response) { instance_double(Net::HTTPSuccess, is_a?: true, body: mock_body) }
      let(:mock_body) do
        {
          "city" => { "name" => "Ho Chi Minh City", "country" => "VN" },
          "list" => [
            { "dt_txt" => "2026-08-28 09:00:00", "main" => { "temp" => 30 } },
            { "dt_txt" => "2026-08-28 12:00:00", "main" => { "temp" => 32 } },
            { "dt_txt" => "2026-08-29 12:00:00", "main" => { "temp" => 33 } }
          ]
        }.to_json
      end

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
      end

      it 'normalizes the city name, fetches forecast and formats data' do
        service = WeatherApiService.new(city_name)
        result = service.call

        expect(Net::HTTP).to have_received(:get_response).with(
          satisfy { |uri| uri.to_s.include?('ho%20chi%20minh') }
        )
        
        expect(result[:success]).to be true
        expect(result[:current]['name']).to eq('Ho Chi Minh City')
        expect(result[:hourly].size).to eq(3) # takes up to 8
        expect(result[:forecast].size).to eq(2) # 2 items at 12:00:00
      end
    end

    context 'when API call fails' do
      let(:city_name) { 'UnknownCity' }
      let(:mock_response) { instance_double(Net::HTTPNotFound, is_a?: false) }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
      end

      it 'returns success false with error message' do
        service = WeatherApiService.new(city_name)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Không tìm thấy thành phố 'UnknownCity'")
      end
    end

    context 'when network error occurs' do
      let(:city_name) { 'Hanoi' }

      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(SocketError.new('getaddrinfo: Name or service not known'))
      end

      it 'rescues the error and returns failure' do
        service = WeatherApiService.new(city_name)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to include("Lỗi kết nối mạng: getaddrinfo")
      end
    end
  end

  describe '.location_call' do
    context 'when lat or lon is missing' do
      it 'returns success false and error message' do
        result = WeatherApiService.location_call('', '105.8')
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Thiếu tọa độ")
      end
    end
  end
end