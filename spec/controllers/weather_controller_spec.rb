require 'rails_helper'

RSpec.describe "Weathers", type: :request do
  describe "GET /" do
    context 'khi mới mở trang chủ (không có params city)' do
      it 'render trang index thành công và hiện màn hình chờ' do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Chưa có dữ liệu hiển thị")
      end
    end

    context 'khi tìm kiếm thành phố hợp lệ' do
      let(:fake_data) do
        {
          'name' => 'Hanoi',
          'sys' => { 'country' => 'VN' },
          'main' => {
            'temp' => 30,
            'feels_like' => 32,
            'humidity' => 70
          },
          'weather' => [
            { 'main' => 'Clear', 'description' => 'bầu trời quang đãng' }
          ],
          'wind' => { 'speed' => 2.5 }
        }
      end

      before do
        allow_any_instance_of(WeatherApiService).to receive(:call).and_return(
          { success: true, data: fake_data }
        )
      end

      it 'hiển thị tên thành phố, nhiệt độ và thông tin thời tiết trên màn hình' do
        get root_path, params: { city: 'Hanoi' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Hanoi")
        expect(response.body).to include("30°C")
        expect(response.body).to include("Bầu trời quang đãng")
      end
    end

    context 'khi nhập sai tên thành phố' do
      before do
        allow_any_instance_of(WeatherApiService).to receive(:call).and_return(
          { success: false, error: "Không tìm thấy thành phố 'xyz123'" }
        )
      end

      it 'hiển thị thông báo lỗi trên màn hình' do
        get root_path, params: { city: 'xyz123' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Không tìm thấy thành phố")
        expect(response.body).to include("xyz123")
      end
    end
    
    context 'khi truyền params lat và lon (lấy thời tiết theo vị trí GPS/IP)' do
      let(:fake_location_data) do
        {
          'name' => 'Hà Nội',
          'sys' => { 'country' => 'VN' },
          'main' => {
            'temp' => 31,
            'feels_like' => 33,
            'humidity' => 70
          },
          'weather' => [
            { 'main' => 'Clear', 'description' => 'nắng nóng' }
          ],
          'wind' => { 'speed' => 3.0 }
        }
      end

      context 'khi lấy vị trí thành công' do
        before do
          allow(WeatherApiService).to receive(:location_call).with('21.0285', '105.8542').and_return(
            { success: true, data: fake_location_data }
          )
        end

        it 'hiển thị thông tin thời tiết dựa theo tọa độ gửi lên' do
          get root_path, params: { lat: '21.0285', lon: '105.8542' }
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Hà Nội")
          expect(response.body).to include("31°C")
        end
      end

      context 'khi lấy vị trí thất bại' do
        before do
          allow(WeatherApiService).to receive(:location_call).and_return(
            { success: false, error: "Lỗi không kết nối được API" }
          )
        end

        it 'hiển thị thông báo lỗi trên màn hình' do
          get root_path, params: { lat: '21.0285', lon: '105.8542' }
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Lỗi không kết nối được API")
        end
      end
    end
  end
end