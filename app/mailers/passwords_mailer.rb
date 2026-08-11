class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: I18n.t("mailers.reset_subject"), to: user.email_address
  end
end
