require "test_helper"

class AdvancedStatsLocalizationTest < ActiveSupport::TestCase
  test "advanced statistics translations have matching non-empty keys" do
    english = flatten(I18n.t("stats.advanced", locale: :en))
    polish = flatten(I18n.t("stats.advanced", locale: :pl))

    assert_equal english.keys.sort, polish.keys.sort
    assert english.values.all?(&:present?)
    assert polish.values.all?(&:present?)
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
