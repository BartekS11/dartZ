require "test_helper"

class SetFlowTest < ActiveSupport::TestCase
  test "on_leg_finished! calls finish! when winner meets leg threshold" do
    match = Match.create!(best_of_legs: 3)
    match.players.create!(name: "Player 1")
    match.players.create!(name: "Player 2")
    match_set = match.match_sets.create!
    winner = match.players.first
    called_with = nil

    match_set.define_singleton_method(:legs_won_by) { |_player| 2 }
    match_set.define_singleton_method(:finish!) { |player| called_with = player }

    match_set.on_leg_finished!(winner)

    assert_equal winner, called_with
  end

  test "on_leg_finished! calls start_next_leg! when winner does not meet leg threshold" do
    match = Match.create!(best_of_legs: 5)
    match.players.create!(name: "Player 1")
    match.players.create!(name: "Player 2")
    match_set = match.match_sets.create!
    winner = match.players.first
    started = false

    match_set.define_singleton_method(:legs_won_by) { |_player| 1 }
    match_set.define_singleton_method(:start_next_leg!) { started = true }

    match_set.on_leg_finished!(winner)

    assert started
  end
end
