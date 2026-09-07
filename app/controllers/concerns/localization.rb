module Localization
  extend ActiveSupport::Concern

  included do
    # Authentication redirects need the locale before generating route URLs.
    prepend_before_action :set_locale
    helper_method :available_locales, :available_locale?, :locale_label
  end

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  private
    def set_locale
      resume_session_optional

      locale = params[:locale].presence || Current.user&.locale.presence || cookies[:locale].presence || I18n.default_locale.to_s
      locale = I18n.default_locale.to_s unless available_locale?(locale)

      I18n.locale = locale
      cookies.permanent[:locale] = { value: locale, httponly: true, same_site: :lax } if cookies[:locale] != locale
      Current.user&.update(locale: locale) if params[:locale].present? && Current.user&.locale != locale
    end

    def available_locales
      I18n.available_locales.map(&:to_s)
    end

    def available_locale?(locale)
      available_locales.include?(locale.to_s)
    end

    def locale_label(locale)
      I18n.t("locales.#{locale}", locale: locale, default: locale.to_s.upcase)
    end
end
