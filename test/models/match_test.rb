require "test_helper"

class MatchTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "display_identifier falls back to database id when no public identifier exists" do
    match = Match.create!

    assert_equal "##{match.id}", match.display_identifier
  end

  test "display_identifier returns match_identifier when present" do
    match = Match.create!(match_identifier: "DZ-CUSTOM-123")

    assert_equal "DZ-CUSTOM-123", match.display_identifier
  end

  test "ensure_match_identifier! creates guest identifier for guest-only match" do
    travel_to Time.zone.local(2026, 5, 4, 10, 0, 0) do
      match = Match.create!
      match.players.create!(name: "Guest 1")
      match.players.create!(name: "Guest 2")

      original_hex = SecureRandom.method(:hex)
      SecureRandom.define_singleton_method(:hex) { |_len = nil| "aabbcc" }

      identifier = match.ensure_match_identifier!

      assert_equal "GUEST-20260504-AABBCC", identifier
      assert_equal identifier, match.reload.match_identifier
    ensure
      SecureRandom.define_singleton_method(:hex, original_hex)
    end
  end

  test "ensure_match_identifier! creates single-user identifier when all signed-in players belong to one user" do
    travel_to Time.zone.local(2026, 5, 4, 10, 0, 0) do
      user = create_user("owner@example.com")
      match = Match.create!
      match.players.create!(name: "Player 1", user: user)
      match.players.create!(name: "Player 2", user: user)

      original_hex = SecureRandom.method(:hex)
      SecureRandom.define_singleton_method(:hex) { |_len = nil| "aabbcc" }

      identifier = match.ensure_match_identifier!

      assert_equal "USER-#{user.id}-20260504-AABBCC", identifier
      assert_equal identifier, match.reload.match_identifier
    ensure
      SecureRandom.define_singleton_method(:hex, original_hex)
    end
  end

  test "ensure_match_identifier! creates multiuser identifier using highest user id" do
    travel_to Time.zone.local(2026, 5, 4, 10, 0, 0) do
      user_a = create_user("a@example.com")
      user_b = create_user("b@example.com")
      match = Match.create!
      match.players.create!(name: "Player 1", user: user_a)
      match.players.create!(name: "Player 2", user: user_b)

      original_hex = SecureRandom.method(:hex)
      SecureRandom.define_singleton_method(:hex) { |_len = nil| "aabbcc" }

      identifier = match.ensure_match_identifier!

      assert_equal "MULTIUSER-#{[user_a.id, user_b.id].max}-20260504-AABBCC", identifier
      assert_equal identifier, match.reload.match_identifier
    ensure
      SecureRandom.define_singleton_method(:hex, original_hex)
    end
  end

  test "ensure_match_identifier! treats mixed guest and signed-in players as single-user match when only one user is involved" do
    travel_to Time.zone.local(2026, 5, 4, 10, 0, 0) do
      user = create_user("signed-in@example.com")
      match = Match.create!
      match.players.create!(name: "Signed In", user: user)
      match.players.create!(name: "Guest")

      original_hex = SecureRandom.method(:hex)
      SecureRandom.define_singleton_method(:hex) { |_len = nil| "aabbcc" }

      identifier = match.ensure_match_identifier!

      assert_equal "USER-#{user.id}-20260504-AABBCC", identifier
    ensure
      SecureRandom.define_singleton_method(:hex, original_hex)
    end
  end

  test "ensure_match_identifier! does not overwrite existing identifier" do
    match = Match.create!(match_identifier: "DZ-EXISTING")

    original_hex = SecureRandom.method(:hex)
    SecureRandom.define_singleton_method(:hex) { |_len = nil| "aabbcc" }

    assert_equal "DZ-EXISTING", match.ensure_match_identifier!
    assert_equal "DZ-EXISTING", match.reload.match_identifier
  ensure
    SecureRandom.define_singleton_method(:hex, original_hex)
  end

  test "ensure_match_identifier! retries when generated identifier already exists" do
    travel_to Time.zone.local(2026, 5, 4, 10, 0, 0) do
      existing = Match.create!(match_identifier: "GUEST-20260504-AABBCC")
      existing.players.create!(name: "Guest 1")
      existing.players.create!(name: "Guest 2")

      match = Match.create!
      match.players.create!(name: "Fresh Guest 1")
      match.players.create!(name: "Fresh Guest 2")

      generated = ["aabbcc", "ddeeff"]
      original_hex = SecureRandom.method(:hex)
      SecureRandom.define_singleton_method(:hex) { |_len = nil| generated.shift }

      identifier = match.ensure_match_identifier!

      assert_equal "GUEST-20260504-DDEEFF", identifier
      assert_equal identifier, match.reload.match_identifier
    ensure
      SecureRandom.define_singleton_method(:hex, original_hex)
    end
  end

  test "match_identifier must be unique" do
    Match.create!(match_identifier: "DZ-UNIQUE")
    duplicate = Match.new(match_identifier: "DZ-UNIQUE")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:match_identifier], "has already been taken"
  end

  private

  def create_user(email)
    User.create!(
      email_address: email,
      password: "password",
      password_confirmation: "password"
    )
  end
end
