class SearchHistoryService
  MAX_LIMIT = 10

  def self.record_search(user, city_name)
    return if user.nil? || city_name.blank?

    history = user.search_histories.find_or_initialize_by(city_name: city_name)
    
    history.updated_at = Time.current
    history.save!

    histories = user.search_histories.order(updated_at: :desc)
    if histories.count > MAX_LIMIT
      histories.offset(MAX_LIMIT).destroy_all
    end
  end

  def self.recent_searches(user, limit: MAX_LIMIT)
    return [] if user.nil?

    user.search_histories.order(updated_at: :desc).limit(limit)
  end
end