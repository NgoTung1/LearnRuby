require 'rails_helper'

RSpec.describe WeatherMailerService do
  let!(:user) { User.create!(email: "test_service@example.com", password: "password123") }
  let!(:favorite) { Favorite.create!(user: user, city_name: "Hanoi") }

  describe ".check_and_send_mail!" do
    context "khi thành phố có thời tiết cực đoan" do
      let(:extreme_weather_data) do
        {
          'name' => 'Hanoi',
          'main' => { 'temp' => 40.0 },
          'wind' => { 'speed' => 18.0 },
          'weather' => [{ 'main' => 'Thunderstorm', 'description' => 'dông bão' }]
        }
      end

      before do
        allow(WeatherApiService).to receive(:fetch_cached)
          .with("Hanoi")
          .and_return({ success: true, data: extreme_weather_data })
      end

      it "kích hoạt gửi email cảnh báo khẩn cấp" do
        mailer_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
        expect(WeatherMailerAlert).to receive(:extreme_weather_alert).and_return(mailer_double)

        WeatherMailerService.check_and_send_mail!
      end
    end

    context "khi thành phố có thời tiết bình thường" do
      let(:normal_weather_data) do
        {
          'name' => 'Hanoi',
          'main' => { 'temp' => 28.0 },
          'wind' => { 'speed' => 3.0 },
          'weather' => [{ 'main' => 'Clear', 'description' => 'bầu trời quang đãng' }]
        }
      end

      before do
        allow(WeatherApiService).to receive(:fetch_cached)
          .with("Hanoi")
          .and_return({ success: true, data: normal_weather_data })
      end

      it "không gửi email cảnh báo" do
        expect(WeatherMailerAlert).not_to receive(:extreme_weather_alert)

        WeatherMailerService.check_and_send_mail!
      end
    end
  end

  describe ".daily_digest!" do
    let(:weather_data) do
      {
        'name' => 'Hanoi',
        'main' => { 'temp' => 28.0 },
        'wind' => { 'speed' => 3.0 },
        'weather' => [{ 'main' => 'Clear', 'description' => 'bầu trời quang đãng' }]
      }
    end

    before do
      allow(WeatherApiService).to receive(:fetch_cached)
        .with("Hanoi")
        .and_return({ success: true, data: weather_data })
    end

    it "kích hoạt gửi email bản tin thời tiết hàng ngày" do
      mailer_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(WeatherMailerAlert).to receive(:daily_digest).and_return(mailer_double)

      WeatherMailerService.daily_digest!
    end
  end
end
