require "test_helper"

class PlayerDartSetupTrackingTest < ActiveSupport::TestCase
  test "snapshot stays stable after user edits current dart setup" do
    user = create_user("snapshot@example.com")
    setup = user.create_dart_setup!(
      manufacturer: "winmau",
      weight_g: 23.0,
      shaft_type: "nylon",
      shaft_length_mm: 40,
      point_length_mm: 32
    )
    match = Match.create!
    player = match.players.build(name: "Snapshot Player", user: user)

    player.assign_dart_setup_snapshot!(setup)
    player.save!
    original_fingerprint = player.dart_setup_fingerprint

    setup.update!(manufacturer: "target", weight_g: 25.0)

    assert_equal original_fingerprint, player.reload.dart_setup_fingerprint
    assert_equal "WINMAU", player.dart_setup_snapshot["manufacturer_label"]
    assert_equal "23.0", player.dart_setup_snapshot["weight_g"]
    assert_equal "WINMAU · 23g · Nylon · 40mm shaft · 32mm point", player.dart_setup_summary
  end
end
