require "test_helper"

class VoiceAnnouncementTest < ActiveSupport::TestCase
  test "only allowlisted sound keys resolve to private files" do
    VoiceAnnouncement::SOUND_KEYS.each do |sound|
      path = VoiceAnnouncement.path_for(sound)
      assert path.file?, "expected #{path} to exist"
      refute path.to_s.include?(Rails.root.join("public").to_s)
    end

    assert_nil VoiceAnnouncement.path_for("../180")
    assert_nil VoiceAnnouncement.path_for("not-a-score")
  end

  test "maps every supported completed turn total to its sound" do
    assert_equal(
      {
        0 => "no-score",
        26 => "26",
        41 => "41",
        45 => "45",
        100 => "100",
        180 => "180"
      },
      VoiceAnnouncement::SOUNDS_BY_TOTAL
    )
  end

  test "broadcast includes protected sound and stable turn event" do
    match = Match.create!
    player = match.players.create!(name: "Alpha")
    match.players.create!(name: "Bravo")
    match.start_first_set!
    turn = match.current_leg.current_turn

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      "match_#{match.id}",
      target: "voice-announcements",
      partial: "voice_announcements/announcement",
      locals: { sound: "180", event_id: turn.public_id }
    )

    VoiceAnnouncement.broadcast_for(turn: turn, total: 180)
  end

  test "unsupported totals do not broadcast" do
    Turbo::StreamsChannel.expects(:broadcast_append_to).never

    VoiceAnnouncement.broadcast_for(turn: stub(leg: stub(match_id: 1)), total: 60)
  end
end
