require "test_helper"

class HasPublicIdTest < ActiveSupport::TestCase
  MODELS_AND_PREFIXES = {
    Match => "m_",
    Tournament => "t_",
    TournamentEntry => "te_",
    TournamentMatch => "tm_",
    TrainingSession => "tr_",
    Leg => "l_",
    Turn => "tu_",
    Player => "p_"
  }.freeze

  test "routed models generate prefixed public IDs and use them in routes" do
    MODELS_AND_PREFIXES.each do |model, prefix|
      record = build_record_for(model)
      record.save!

      assert_match(/\A#{Regexp.escape(prefix)}[0-9A-Za-z]{16}\z/, record.public_id)
      assert_equal record.public_id, record.to_param
      assert_equal record, model.find_by_public_id!(record.public_id)
      assert_raises(ActiveRecord::RecordNotFound) { model.find_by_public_id!(record.id.to_s) }
    end
  end

  private

  def build_record_for(model)
    case model.name
    when "Match"
      Match.new(best_of_legs: 1, best_of_sets: 1)
    when "Tournament"
      Tournament.new(title: "Public ID Cup", format_type: "playoffs", best_of_legs: 1, best_of_sets: 1)
    when "TournamentEntry"
      tournament = Tournament.create!(title: "Entry Cup", format_type: "playoffs", best_of_legs: 1, best_of_sets: 1)
      tournament.entries.build(name: "Entry", seed: 1)
    when "TournamentMatch"
      tournament = Tournament.create!(title: "Match Cup", format_type: "playoffs", best_of_legs: 1, best_of_sets: 1)
      round = tournament.rounds.create!(number: 1, name: "Round 1", stage_type: "playoffs")
      round.tournament_matches.build(tournament: tournament, position: 1, best_of_legs: 1, best_of_sets: 1)
    when "TrainingSession"
      user = User.create!(email_address: "public-training@example.com", password: "password")
      user.training_sessions.build(mode: "around_the_clock")
    when "Leg"
      match = Match.create!(best_of_legs: 1, best_of_sets: 1)
      match_set = match.match_sets.create!
      match_set.legs.build(match: match)
    when "Turn"
      match = Match.create!(best_of_legs: 1, best_of_sets: 1)
      player = match.players.create!(name: "Player")
      match_set = match.match_sets.create!
      leg = match_set.legs.create!(match: match)
      leg.turns.build(player: player)
    when "Player"
      match = Match.create!(best_of_legs: 1, best_of_sets: 1)
      match.players.build(name: "Player")
    else
      raise "Unsupported model #{model.name}"
    end
  end
end
