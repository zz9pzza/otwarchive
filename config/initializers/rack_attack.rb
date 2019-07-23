# frozen_string_literal: true

Rack::Attack.throttled_response = lambda do |env|
  match_data = env['rack.attack.match_data']
  now = match_data[:epoch_time]

  headers = {
    'RateLimit-Limit' => match_data[:limit].to_s,
    'RateLimit-Remaining' => '0',
    'RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
  }

  [429, headers, ["Throttled\n"]]
end

Rack::Attack.throttle('guest_post', limit: ArchiveConfig.GUEST_LIMIT || 6, period: ArchiveConfig.GUEST_PERIOD || 60) do |req|
  if req.post? && (req.env['rack.session'].nil? || req.env['rack.session']["warden.user.user.key"].nil?)
    req.ip
  end
end

Rack::Attack.throttle('logged_in_kudos', limit: ArchiveConfig.USER_KUDOS_LIMIT || 6, period: ArchiveConfig.USER_KUDOS_LIMIT || 30) do |req|
  if req.post? && (req.path == '/kudos.js' || req.path == '/kudos') && \
     req.env['rack.session'].present? && req.env['rack.session']["warden.user.user.key"].present?
    req.env['rack.session']["warden.user.user.key"][0][0]
  end
end

Rack::Attack.throttle('logged_in_works', limit: ArchiveConfig.USER_WORKS_LIMIT || 6, period: ArchiveConfig.USER_WORKS_LIMIT || 600) do |req|
  if req.post? && req.path == '/works' && \
     req.env['rack.session'].present? && req.env['rack.session']["warden.user.user.key"].present?
    req.env['rack.session']["warden.user.user.key"][0][0]
  end
end

Rack::Attack.throttle('logged_in_comments', limit: ArchiveConfig.USER_COMMENTS_LIMIT || 6, period: ArchiveConfig.USER_COMMENTS_LIMIT || 120) do |req|
  if req.post? && req.path.match(%r{^\/chapters\/.*\/comments$}) && \
     req.env['rack.session'].present? && req.env['rack.session']["warden.user.user.key"].present?
    req.env['rack.session']["warden.user.user.key"][0][0]
  end
end
