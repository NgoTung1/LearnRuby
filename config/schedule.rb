# Cấu hình môi trường và đường dẫn ghi log cho Cron
set :environment, "development"
set :output, "log/cron.log"

every 1.hour do
  rake "weather:check_alerts"
end

every 1.day, at: '7:00 am' do
  rake "weather:send_daily_digest"
end
