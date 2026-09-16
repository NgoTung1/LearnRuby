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

  def get_fa_icon(code)
    case code.to_s
    when /01/ then { class: "fas fa-sun", color: "#f59e0b" }
    when /02/, /03/, /04/ then { class: "fas fa-cloud-sun", color: "#64748b" }
    when /09/, /10/ then { class: "fas fa-cloud-showers-heavy", color: "#3b82f6" }
    when /11/ then { class: "fas fa-bolt", color: "#eab308" }
    when /13/ then { class: "fas fa-snowflake", color: "#38bdf8" }
    else { class: "fas fa-cloud", color: "#94a3b8" }
    end
  end

  def get_weekday(date_string)
    return "" if date_string.blank?
    days = ["Chủ nhật", "Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7"]
    days[Date.parse(date_string).wday]
  rescue StandardError
    ""
  end
end
