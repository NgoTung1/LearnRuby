module ApplicationHelper
  def time_ago_in_words_vi(time)
    return "" if time.blank?

    seconds = (Time.current - time).to_i

    case seconds
    when 0..59
      "Vừa xong"
    when 60..3599
      "#{seconds / 60} phút trước"
    when 3600..86399
      "#{seconds / 3600} giờ trước"
    when 86400..2591999
      "#{seconds / 86400} ngày trước"
    else
      time.strftime("%d/%m/%Y")
    end
  end
end
