class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = (params[:selected_locale].presence || params[:locale]).to_s
    locale = I18n.default_locale.to_s unless available_locale?(locale)

    cookies.permanent[:locale] = { value: locale, httponly: true, same_site: :lax }
    Current.user&.update(locale: locale)

    redirect_to localized_return_path(locale), allow_other_host: false
  end

  private

  def localized_return_path(locale)
    uri = URI.parse(params[:return_to].presence || root_path)
    query = Rack::Utils.parse_nested_query(uri.query).merge("locale" => locale)
    uri.query = query.to_query
    uri.to_s.presence || root_path(locale: locale)
  rescue URI::InvalidURIError
    root_path(locale: locale)
  end
end
