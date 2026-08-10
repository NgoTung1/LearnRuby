require 'rails_helper'

RSpec.describe WeatherMailerAlert, type: :mailer do
  let(:user) { User.create!(email: "test_alert@example.com", password: "password123") }

  describe "extreme_weather_alert" do
    let(:alerts) do
      [
        {
          city: "Hanoi",
          condition: "Thunderstorm",
          temp: 39.5,
          wind: 16.0,
          advice: "Thời tiết cực đoan: Thunderstorm; Nhiệt độ quá cao (39.5°C); Gió rất mạnh (16.0 m/s)"
        }
      ]
    end

    let(:mail) { WeatherMailerAlert.extreme_weather_alert(user, alerts) }

    it "Gửi đúng địa chỉ email nhận" do
      expect(mail.to).to eq([user.email])
    end

    it "Tiêu đề email chứa thông tin cảnh báo" do
      expect(mail.subject).to include("[Cảnh báo thời tiết bất thường]")
    end

    it "Nội dung email phải chứa thông tin thành phố và cảnh báo" do
      expect(mail.body.encoded).to include("Hanoi")
      expect(mail.body.encoded).to include("39.5°C")
    end
  end

  describe "daily_digest" do
    let(:weather_list) do
      [
        {
          'name' => 'Danang',
          'main' => { 'temp' => 28, 'feels_like' => 30, 'humidity' => 75 },
          'weather' => [{ 'description' => 'mưa rào nhẹ' }],
          'wind' => { 'speed' => 4.2 }
        }
      ]
    end

    let(:mail) { WeatherMailerAlert.daily_digest(user, weather_list) }

    it "Gửi đúng địa chỉ email nhận" do
      expect(mail.to).to eq([user.email])
    end

    it "Tiêu đề email chứa thông tin bản tin ngày" do
      expect(mail.subject).to include("Thời tiết ngày")
    end

    it "Nội dung email chứa thông tin thời tiết thành phố" do
      expect(mail.body.encoded).to include("Danang")
      expect(mail.body.encoded).to include("28°C")
    end
  end
end
