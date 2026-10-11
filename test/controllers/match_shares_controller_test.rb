require "test_helper"

class MatchSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user("match-share-owner@example.com")
    login_as(@owner)
  end

  test "registered owner can create anonymous result share and revoke it" do
    match = finished_match(owner: @owner)

    post share_match_path(match)

    assert_redirected_to match_path(match)
    token = match.reload.review_share_token
    assert token.present?

    delete session_path
    get match_share_path(token)

    assert_response :success
    assert_select "h1", "Match complete"
    assert_select "strong", text: "Player 1"
    assert_no_match(/match-share-owner@example.com|Owner/, response.body)
    assert_select "table", count: 0
    assert_no_match(/data-match-view/, response.body)
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow, noarchive", response.headers["X-Robots-Tag"]

    login_as(@owner)
    delete share_match_path(match)
    assert_nil match.reload.review_share_token

    delete session_path
    get match_share_path(token)
    assert_response :not_found
  end

  test "cannot create a share for an unfinished match or someone else's match" do
    unfinished = Match.create!
    unfinished.players.create!(name: "Owner", user: @owner)
    unfinished.players.create!(name: "Guest")

    post share_match_path(unfinished)
    assert_redirected_to match_path(unfinished)
    assert_nil unfinished.reload.review_share_token

    other_user = create_user("other-match-owner@example.com")
    other_match = finished_match(owner: other_user)
    post share_match_path(other_match)
    assert_redirected_to matches_path
    assert_nil other_match.reload.review_share_token
  end

  test "premium review shows leg timeline while free is sent to billing" do
    match = finished_match(owner: @owner, with_turns: true)

    get review_match_path(match)
    assert_redirected_to billing_path

    @owner.update!(account_tier: "premium")
    get review_match_path(match)

    assert_response :success
    assert_select "h2", text: "Leg-by-leg scoring timeline"
    assert_select "h2", text: "Pro match analysis", count: 0
    assert_select "td", text: "60"
  end

  test "pro review includes additional analysis" do
    match = finished_match(owner: @owner)
    @owner.update!(account_tier: "pro")

    get review_match_path(match)

    assert_response :success
    assert_select "h2", text: "Pro match analysis"
  end

  private

  def finished_match(owner:, with_turns: false)
    match = Match.create!
    owner_player = match.players.create!(name: "Owner", user: owner)
    opponent = match.players.create!(name: "Opponent")
    now = Time.current
    set = match.match_sets.create!(finished_at: now, winner_id: owner_player.id)
    leg = set.legs.create!(match: match, winner_id: owner_player.id, finished_at: now, starting_score: match.starting_score)
    if with_turns
      leg.turns.create!(player: owner_player, total_score: 60, completed_at: now)
      leg.turns.create!(player: opponent, total_score: 45, completed_at: now + 1.second)
    end
    match.update!(finished_at: now)
    match
  end
end
