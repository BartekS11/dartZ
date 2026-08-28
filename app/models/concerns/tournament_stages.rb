module TournamentStages
  extend ActiveSupport::Concern

  def effective_group_count(entries_count: entries.count)
    requested_count = group_count.presence || 2
    [ [ requested_count, entries_count.to_i / 2 ].min, 1 ].max
  end

  def playoff_enabled?
    format_type.in?(%w[groups playoffs groups_playoffs swiss_playoffs])
  end

  def group_stage_enabled?
    format_type.in?(%w[groups groups_playoffs])
  end

  def swiss_stage_enabled?
    format_type.in?(%w[swiss swiss_playoffs])
  end

  def combined_with_playoffs?
    format_type.in?(%w[groups groups_playoffs swiss_playoffs])
  end

  def effective_swiss_round_count
    swiss_round_count.presence || [ Math.log2([ entries.count, 2 ].max).ceil, 1 ].max
  end

  def swiss_rounds
    rounds.where(stage_type: "swiss").order(:number)
  end

  def next_swiss_round_number
    swiss_rounds.maximum(:number).to_i + 1
  end

  def can_generate_next_swiss_round?
    return false unless swiss_stage_enabled?
    return false if next_swiss_round_number > effective_swiss_round_count

    last_round = swiss_rounds.last
    return true if last_round.nil?

    last_round.tournament_matches.exists? && last_round.tournament_matches.where.not(status: "complete").none?
  end

  def can_generate_next_playoff_round?
    return false unless playoff_enabled?

    rounds.where(stage_type: "playoffs").where.not(status: "complete").none?
  end
end
