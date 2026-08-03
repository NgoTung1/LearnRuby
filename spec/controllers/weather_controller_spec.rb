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
  end
end