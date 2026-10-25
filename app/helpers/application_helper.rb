module ApplicationHelper
  def landing_page?
    controller_path == "home" && action_name == "show"
  end

  # Keep language variants distinct while dropping tracking and unrelated params.
  def landing_canonical_url(locale = I18n.locale)
    root_url(locale: locale.to_s == I18n.default_locale.to_s ? nil : locale)
  end
end
