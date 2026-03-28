module JsonWebToken
  SECRET = Rails.application.secret_key_base
  EXPIRY = 30.days

  def self.encode(payload)
    payload[:exp] = EXPIRY.from_now.to_i
    JWT.encode(payload, SECRET, "HS256")
  end

  def self.decode(token)
    body = JWT.decode(token, SECRET, true, algorithm: "HS256")[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end
end
