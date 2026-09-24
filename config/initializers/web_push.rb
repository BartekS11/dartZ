Rails.application.config.x.web_push = ActiveSupport::OrderedOptions.new
Rails.application.config.x.web_push.public_key = ENV["VAPID_PUBLIC_KEY"].presence || Rails.application.credentials.dig(:web_push, :public_key)
Rails.application.config.x.web_push.private_key = ENV["VAPID_PRIVATE_KEY"].presence || Rails.application.credentials.dig(:web_push, :private_key)
Rails.application.config.x.web_push.subject = ENV["VAPID_SUBJECT"].presence || Rails.application.credentials.dig(:web_push, :subject)
Rails.application.config.x.web_push.delivery_adapter = nil
if Rails.env.test?
  Rails.application.config.x.web_push.public_key ||= "test-vapid-public-key"
  Rails.application.config.x.web_push.private_key ||= "test-vapid-private-key"
  Rails.application.config.x.web_push.subject ||= "mailto:test@example.com"
end

if Rails.env.production? && Rails.application.config.x.roadmap_features[:web_push]
  missing = %i[public_key private_key subject].select { |key| Rails.application.config.x.web_push.public_send(key).blank? }
  raise "Web Push is enabled but missing: #{missing.map { |key| "VAPID_#{key.to_s.upcase}" }.join(", ")}" if missing.any?

  encryption_missing = %i[primary_key deterministic_key key_derivation_salt].select do |key|
    Rails.application.credentials.dig(:active_record_encryption, key).blank?
  end
  if encryption_missing.any?
    raise "Web Push requires Active Record encryption credentials: #{encryption_missing.join(", ")}"
  end

  subject = Rails.application.config.x.web_push.subject
  unless subject.start_with?("mailto:", "https://")
    raise "VAPID_SUBJECT must be a mailto: or https: URI"
  end
end
