class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "DartZ <noreply@dartz.pl>")
  layout "mailer"
end
