class Rack::Attack
  throttle('req/ip', limit: 60, period: 1.minute) do |req|
    req.ip
  end

  throttle('weather_search/ip', limit: 10, period: 1.minute) do |req|
    if req.path == '/' && (req.GET['city'].present? || req.params['city'].present?)
      req.ip
    end
  end

  throttle('logins/ip', limit: 5, period: 1.minute) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end
end