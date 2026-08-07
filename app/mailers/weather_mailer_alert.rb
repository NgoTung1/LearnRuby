class WeatherMailerAlert < ApplicationMailer
  default from: 'Weather on Rails <no-reply@wor.com>'
  def extreme_weather_alert(user, alerts)
    @user = user
    @alerts = alerts
    mail(to: @user.email, subject: "[Cảnh báo thời tiết bất thường]")
  end

  def daily_digest(user, weather_list)
    @user = user
    @weather_list = weather_list
    mail(to: @user.email, subject: "Thời tiết ngày #{Date.today.strftime('%d/%m/%Y')}")
  end
end