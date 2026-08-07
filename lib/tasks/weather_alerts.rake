namespace :weather do
  desc "Quét và gửi email cảnh báo thời tiết khẩn cấp"
  task check_alerts: :environment do
    puts "[#{Time.current}] Bắt đầu quét cảnh báo thời tiết khẩn cấp..."
    WeatherMailerService.check_and_send_mail!
    puts "[#{Time.current}] Hoàn thành quét cảnh báo!"
  end

  desc "Gửi bản tin thời tiết hàng ngày"
  task send_daily_digest: :environment do
    puts "[#{Time.current}] Bắt đầu gửi bản tin thời tiết hàng ngày..."
    WeatherMailerService.daily_digest!
    puts "[#{Time.current}] Hoàn thành gửi bản tin!"
  end
end
