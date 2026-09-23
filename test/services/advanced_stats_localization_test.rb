require "test_helper"

class AdvancedStatsLocalizationTest < ActiveSupport::TestCase
  test "advanced statistics translations have matching non-empty keys" do
    english = flatten(I18n.t("stats.advanced", locale: :en))

    User::LOCALES.each do |locale|
      translation = flatten(I18n.t("stats.advanced", locale: locale))
      assert_equal english.keys.sort, translation.keys.sort, "Key mismatch for #{locale}"
      assert translation.values.all?(&:present?), "Blank translation for #{locale}"
    end
  end

  private

  def flatten(value, prefix = nil, output = {})
    value.each do |key, child|
      path = [ prefix, key ].compact.join(".")
      child.is_a?(Hash) ? flatten(child, path, output) : output[path] = child
    end
    output
  end
end
