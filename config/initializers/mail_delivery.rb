# Shared by development and production; tests always use the test delivery adapter.
unless Rails.env.test?
  Rails.application.configure do
    if ENV["SMTP_ADDRESS"].present?
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.raise_delivery_errors = true
      config.action_mailer.smtp_settings = {
        address: ENV.fetch("SMTP_ADDRESS"),
        port: Integer(ENV.fetch("SMTP_PORT", "587")),
        user_name: ENV["SMTP_USERNAME"].presence,
        password: ENV["SMTP_PASSWORD"].presence,
        authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain"),
        domain: ENV.fetch("SMTP_DOMAIN", "dartz.pl"),
        enable_starttls_auto: true
      }.compact
    end
  end
end
