require "test_helper"

class AdvancedStatsFiltersTest < ActiveSupport::TestCase
  test "normalizes supported filters and strict dates" do
    opponent = create_match_player
    values = AdvancedStatsFilters.new(ActionController::Parameters.new(
      from: "2026-09-01",
      to: "2026-09-10",
      starting_score: "501",
      opponent_id: opponent.public_id,
      match_source: "casual",
      dart_setup_id: "0123456789abcdef",
      double_in: "false",
      double_out: "true"
    )).to_h

    assert_equal Date.new(2026, 9, 1), values[:from]
    assert_equal Date.new(2026, 9, 10), values[:to]
    assert_equal 501, values[:starting_score]
    assert_equal opponent.public_id, values[:opponent_id]
    assert_equal "casual", values[:match_source]
  end

  test "rejects unsupported enumerations booleans and opaque IDs" do
    {
      starting_score: "500",
      match_source: "all",
      double_in: "maybe",
      opponent_id: "1",
      dart_setup_id: "unsafe"
    }.each do |key, value|
      error = assert_raises(Api::V1::RequestParameters::InvalidParameter) do
        AdvancedStatsFilters.new(ActionController::Parameters.new(key => value)).to_h
      end
      assert_equal key.to_s, error.parameter
    end
  end

  private

  def create_match_player
    match = Match.create!
    match.players.create!(name: "Filter Opponent")
  end
end
