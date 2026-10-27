require "e2e_helper"

class MatchDartLimitFlowTest < E2EIntegrationTest
  test "zero total crosses the per-player limit and renders ordinary completion" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    player = turn.player
    seed_darts(player, 996, leg: turn.leg)

    submit_turn_total(turn, 0)
    assert_response :redirect
    assert_not match.reload.finished?
    assert_equal 999, match.safety_darts_for(player)
    submit_turn_total(match.current_leg.current_turn, 0)
    limiting_turn = match.reload.current_leg.current_turn
    submit_turn_total(limiting_turn, 0, format: :turbo_stream)
    assert_response :success
    assert match.reload.finished?
    assert_nil match.winner
    assert limiting_turn.reload.completed?
    assert limiting_turn.leg.reload.finished?
    assert limiting_turn.leg.match_set.reload.finished?
    assert_nil match.current_leg
    assert_equal 1002, match.safety_darts_for(player)
    assert_includes response.body, "game-over-section"
    assert_not_includes response.body, "finish-popup-overlay"
    assert_not_includes response.body.downcase, "dart limit"
    assert_not_includes response.body.downcase, "spam"

    get match_path(match)
    assert_response :success
    assert_select ".theme-game-over"
    assert_select "#match-score-input", count: 0
    assert_select ".finish-popup-overlay", count: 0
  end

  test "the thousandth individual dart stops before awarding a checkout" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    seed_darts(turn.player, 999, leg: turn.leg)
    turn.leg_player.update!(score: 40)

    post turn_throws_path(turn), params: { throw: { segment: 20, multiplier: "double" } }
    assert_response :redirect
    assert match.reload.finished?
    assert_nil match.winner
    assert_nil MatchStatePresenter.new(match).winner
    assert_equal 1000, match.safety_darts_for(turn.player)
    assert_equal 40, turn.leg_player.reload.score
    assert_nil turn.leg.reload.winner_id
  end

  test "counts are per player not combined and totals count as three" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    match.players.each { |player| seed_darts(player, 600, leg: turn.leg) }
    submit_turn_total(turn, 60)
    assert_response :redirect
    assert_not match.reload.finished?
    assert_equal 603, match.safety_darts_for(turn.player)
    assert_equal 441, match.score_for(turn.player)
  end

  test "single darts below the threshold count as one" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    seed_darts(turn.player, 996, leg: turn.leg)
    3.times do
      ThrowSubmission.call(turn: turn, throw_attributes: { segment: 0, multiplier: "miss" })
    end
    assert_equal 999, match.reload.safety_darts_for(turn.player)
    assert_not match.finished?
  end

  test "history from earlier sets and legacy direct legs also counts" do
    match = create_guest_match(best_of_legs: 3, best_of_sets: 3)
    turn = match.current_leg.current_turn
    older_set = match.match_sets.create!(created_at: 2.days.ago, finished_at: 1.day.ago)
    older_leg = match.all_legs.create!(match_set: older_set, created_at: 2.days.ago, finished_at: 1.day.ago)
    direct_leg = match.all_legs.create!(created_at: 2.days.ago, finished_at: 1.day.ago)
    seed_darts(turn.player, 600, leg: older_leg)
    seed_darts(turn.player, 399, leg: direct_leg)
    submit_turn_total(turn, 0)
    assert_response :redirect
    assert match.reload.finished?
    assert_nil match.winner
  end

  test "invalid total submissions cannot bypass the limit" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    seed_darts(turn.player, 999, leg: turn.leg)
    submit_turn_total(turn, 9999)
    assert_response :redirect
    assert match.reload.finished?
    assert_nil match.winner
  end

  test "completed and stale turn submissions do not add records or change totals" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    submit_turn_total(turn, 0)
    assert_response :redirect
    assert_no_difference [ "Throw.count", "Turn.count" ] do
      ThrowSubmission.call(turn: turn, total: 180)
      ThrowSubmission.call(turn: turn, throw_attributes: { segment: 20, multiplier: "triple" })
    end
    assert_equal 0, turn.reload.total_score
    assert_not match.reload.finished?
  end

  test "finished match ignores replay submissions and undo" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    seed_darts(turn.player, 999, leg: turn.leg)
    submit_turn_total(turn, 0)
    assert match.reload.finished?
    finished_at = match.finished_at
    assert_no_difference [ "Throw.count", "Turn.count" ] do
      ThrowSubmission.call(turn: turn, total: 180)
      ThrowSubmission.call(turn: turn, throw_attributes: { segment: 20, multiplier: "triple" })
      assert_not match.undo_last_throw!(mode: "total")
    end
    assert_equal finished_at, match.reload.finished_at
    assert_nil match.winner
  end

  test "reopened total turns count remaining records not the previous full visit" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    submit_turn_total(turn, 60)
    assert_equal 3, match.reload.safety_darts_for(turn.player)
    assert match.undo_last_throw!(mode: "single")
    assert_equal 0, match.reload.safety_darts_for(turn.player)
    ThrowSubmission.call(turn: turn.reload, throw_attributes: { segment: 0, multiplier: "miss" })
    assert_equal 1, match.reload.safety_darts_for(turn.player)
    assert_nil turn.reload.total_score
  end

  test "API total submission finishes without exposing the safeguard" do
    post "/api/v1/auth/guest"
    token = json_response.fetch("token")
    headers = { "Authorization" => "Bearer #{token}" }
    post "/api/v1/matches", params: { player1_name: "API A", player2_name: "API B" }, headers: headers
    assert_response :created
    match = Match.find_by!(public_id: json_response.fetch("id"))
    turn = match.current_leg.current_turn
    seed_darts(turn.player, 999, leg: turn.leg)
    post "/api/v1/matches/#{match.public_id}/throws", params: { total: 0 }, headers: headers
    assert_response :created
    assert_equal true, json_response.fetch("finished")
    assert_nil json_response.fetch("winner")
    assert_nil json_response.fetch("current_turn_id")
    assert_not_includes response.body, "limit"
    assert_not_includes response.body, "spam"
  end

  test "built-in bot stops at its thousandth dart and does not enqueue another turn" do
    match = create_guest_match
    turn = match.current_leg.current_turn
    turn.player.update!(bot: true, bot_level: 1)
    seed_darts(turn.player, 999, leg: turn.leg)
    BotService.stubs(:play_turn).returns("throws" => [ "S20", "S20", "S20" ])
    BotTurnJob.expects(:perform_later).never
    BotTurnJob.perform_now(turn.id)
    assert match.reload.finished?
    assert_nil match.winner
    assert_equal 1, turn.throws.count
    assert_equal 1000, match.safety_darts_for(turn.player)
    assert_no_difference "Throw.count" do
      BotTurnJob.perform_now(turn.id)
    end
  end

  test "tournament completion records no winner and does not advance arbitrary knockout participants" do
    %w[single_elimination double_elimination].each do |mode|
      post tournaments_path, params: { tournament: {
        title: "Capped #{mode}", format_type: "playoffs", best_of_legs: 1, best_of_sets: 1,
        playoff_mode: mode, entry_names: "Alpha\nBravo\nCharlie\nDelta"
      } }
      tournament = Tournament.order(:created_at).last
      post start_tournament_path(tournament, admin_token: tournament.admin_token)
      assert_response :redirect
      tournament_match = tournament.reload.tournament_matches.order(:position).first
      post launch_tournament_tournament_match_path(tournament, tournament_match, admin_token: tournament.admin_token)
      assert_response :redirect
      match = tournament_match.reload.linked_match
      turn = match.current_leg.current_turn
      seed_darts(turn.player, 999, leg: turn.leg)
      submit_turn_total(turn, 0)
      assert_response :redirect
      assert_equal "complete", tournament_match.reload.status
      assert_nil tournament_match.winner_entry
      assert_nil match.reload.winner
      other_match = tournament.tournament_matches.where.not(id: tournament_match.id).first
      other_match.update!(status: "complete", winner_entry: other_match.home_entry, completed_at: Time.current)
      assert_no_difference "TournamentRound.count" do
        TournamentProgressor.new(tournament).call
        PlayoffProgressor.new(tournament).call
      end
      assert_not_equal "complete", tournament.reload.status
    end
  end

  private

  def seed_darts(player, count, leg:)
    visits, singles = count.divmod(3)
    now = 1.hour.ago
    rows = Array.new(visits) do
      { leg_id: leg.id, player_id: player.id, public_id: "tu_#{SecureRandom.hex(12)}",
        total_score: 0, completed_at: now, created_at: now, updated_at: now }
    end
    Turn.insert_all!(rows) if rows.any?
    if singles.positive?
      turn = leg.turns.create!(player: player, completed_at: now, created_at: now)
      singles.times { turn.throws.create!(segment: 0, multiplier: "miss") }
    end
  end
end
