require "test_helper"

class PlayerOrderControlTest < ActionView::TestCase
  test "enabled swap control is shown during an empty opening turn" do
    match = started_match

    render_control(match)

    assert_select "button[aria-label='#{I18n.t("live_match.swap_players")}']" do |buttons|
      refute buttons.first.has_attribute?("disabled")
    end
  end

  test "swap control remains visible but disabled from turn four" do
    match = started_match
    3.times do
      ThrowSubmission.call(turn: match.reload.current_leg.current_turn, total: 0)
    end

    render_control(match.reload)

    assert_select "button[aria-label='#{I18n.t("live_match.swap_players")}'][disabled]", count: 1
  end

  test "swap control is disabled after a dart is entered" do
    match = started_match
    ThrowSubmission.call(
      turn: match.current_leg.current_turn,
      throw_attributes: { segment: 20, multiplier: "single" }
    )

    render_control(match.reload)

    assert_select "button[aria-label='#{I18n.t("live_match.swap_players")}'][disabled]", count: 1
  end

  private
    def started_match
      match = Match.create!(guest_token: SecureRandom.hex(24))
      match.players.create!(name: "Alice")
      match.players.create!(name: "Bob")
      match.start_first_set!
      match
    end

    def render_control(match)
      render partial: "matches/player_order_control",
        locals: { match: match, presenter: MatchStatePresenter.new(match) }
    end
end
