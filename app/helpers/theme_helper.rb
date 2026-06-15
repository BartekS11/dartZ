module ThemeHelper
  def dartz_theme
    @dartz_theme ||= begin
      raw = YAML.safe_load(
        File.read(Rails.root.join("config/dartz_theme.yml")),
        aliases: true
      )
      raw.fetch(Rails.env, raw.fetch("default"))
    end
  end

  def theme_app_name
    dartz_theme["app_name"] || "DartZ"
  end

  def theme_app_accent
    dartz_theme["app_accent"] || "Z"
  end

  def theme_logo_mode
    dartz_theme["logo_mode"] || "target"
  end

  def theme_colors
    dartz_theme.fetch("colors", {})
  end

  def theme_css_variables
    theme_colors.map { |key, value| "--theme-#{key.to_s.tr('_', '-')}: #{value}" }.join("; ")
  end
end
