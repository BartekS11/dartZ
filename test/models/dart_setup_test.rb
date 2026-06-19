require "test_helper"

class DartSetupTest < ActiveSupport::TestCase
  test "valid setup" do
    setup = DartSetup.new(
      user: create_user("setup@example.com"),
      manufacturer: "target",
      weight_g: 23.5,
      shaft_type: "carbon",
      shaft_length_mm: 40,
      point_length_mm: 32
    )

    assert setup.valid?
    assert_equal "Target · 23.5g · Carbon · 40mm shaft · 32mm point", setup.display_summary
    assert setup.fingerprint.present?
    assert_equal "Target", setup.snapshot_attributes["manufacturer_label"]
  end

  test "rejects unsupported manufacturer" do
    setup = DartSetup.new(
      user: create_user("invalid-manufacturer@example.com"),
      manufacturer: "unknown",
      weight_g: 23.5,
      shaft_type: "carbon",
      shaft_length_mm: 40,
      point_length_mm: 32
    )

    assert_not setup.valid?
  end

  test "rejects unsupported shaft type" do
    setup = DartSetup.new(
      user: create_user("invalid-setup@example.com"),
      manufacturer: "target",
      weight_g: 23.5,
      shaft_type: "wood",
      shaft_length_mm: 40,
      point_length_mm: 32
    )

    assert_not setup.valid?
  end
end
