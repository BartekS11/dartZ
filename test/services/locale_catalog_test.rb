require "test_helper"

class LocaleCatalogTest < ActiveSupport::TestCase
  test "every supported locale has the same complete, nonblank catalog as English" do
    english = flatten(YAML.safe_load_file(Rails.root.join("config/locales/en.yml"), aliases: true).fetch("en"))

    %w[nl es].each do |locale|
      catalog = YAML.safe_load_file(Rails.root.join("config/locales/#{locale}.yml"), aliases: true).fetch(locale)
      translation = flatten(catalog)
      assert_equal english.keys.sort, translation.keys.sort, "Catalog key mismatch for #{locale}"
      blank_keys = translation.select { |_key, value| value.is_a?(String) && value.blank? }.keys
      english_blank_keys = english.select { |_key, value| value.is_a?(String) && value.blank? }.keys
      assert_equal english_blank_keys, blank_keys, "Blank catalog value for #{locale}"
    end
  end

  test "new locale translations preserve English interpolation variables" do
    english = flatten(YAML.safe_load_file(Rails.root.join("config/locales/en.yml"), aliases: true).fetch("en"))

    %w[nl es].each do |locale|
      translated = flatten(YAML.safe_load_file(Rails.root.join("config/locales/#{locale}.yml"), aliases: true).fetch(locale))
      english.each do |key, value|
        next unless value.is_a?(String)

        assert_equal placeholders(value), placeholders(translated.fetch(key)), "Interpolation mismatch at #{locale}.#{key}"
      end
    end
  end

  test "language selector labels include all supported languages" do
    User::LOCALES.each do |locale|
      assert I18n.t("locales.#{locale}", locale: locale).present?
    end
  end

  private

  def placeholders(value)
    value.scan(/%\{[^}]+\}|%\w/).sort
  end

  def flatten(value, prefix = nil, output = {})
    value.each do |key, child|
      path = [ prefix, key ].compact.join(".")
      child.is_a?(Hash) ? flatten(child, path, output) : output[path] = child
    end
    output
  end
end
