require 'rails_helper'

RSpec.describe WeatherApiService do
  let(:city_name) { 'Hanoi' }
  let(:service) { WeatherApiService.new(city_name) }

  describe '#call' do
    context 'khi tên thành phố rỗng' do
      let(:city_name) { '' }
      it 'trả về success: false và error là nil' do
        result = service.call
        expect(result[:success]).to be false
        expect(result[:error]).to be_nil
      end
    end

    context 'khi gọi API thành công' do
      let(:mock_json) do
        {
          'name' => 'Hanoi',
          'sys' => { 'country' => 'VN' },
          'main' => { 'temp' => 30, 'feels_like' => 32, 'humidity' => 70 },
          'weather' => [{ 'main' => 'Clear', 'description' => 'bầu trời quang đãng', 'icon' => '01d' }],
          'wind' => { 'speed' => 2.5 }
        }.to_json
      end

      before do
        response = instance_double(Net::HTTPSuccess, is_a?: true, body: mock_json)
        allow(Net::HTTP).to receive(:get_response).and_return(response)
      end

      it 'trả về success: true kèm dữ liệu thời tiết' do
        result = service.call
        expect(result[:success]).to be true
        expect(result[:data]['name']).to eq('Hanoi')
        expect(result[:data]['main']['temp']).to eq(30)
      end
    end

    context 'khi không tìm thấy thành phố' do
      before do
        response = instance_double(Net::HTTPNotFound, is_a?: false)
        allow(Net::HTTP).to receive(:get_response).and_return(response)
      end

      it 'trả về success: false kèm thông báo lỗi' do
        result = service.call
        expect(result[:success]).to be false
        expect(result[:error]).to include("Không tìm thấy thành phố")
      end
    end
  end
end