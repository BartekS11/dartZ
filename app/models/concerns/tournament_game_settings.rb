module TournamentGameSettings
  extend ActiveSupport::Concern

  def playoff_game_settings
    {
      starting_score: playoff_starting_score || starting_score,
      double_in: playoff_double_in.nil? ? double_in : playoff_double_in,
      double_out: playoff_double_out.nil? ? double_out : playoff_double_out
    }
  end

  def group_match_settings
    { best_of_legs: best_of_legs, best_of_sets: best_of_sets, **game_settings }
  end

  def playoff_match_settings(round_role: nil)
    legs = case round_role
    when :semifinal then semifinal_best_of_legs.presence || playoff_best_of_legs
    when :final then final_best_of_legs.presence || playoff_best_of_legs
    else playoff_best_of_legs
    end

    { best_of_legs: legs || best_of_legs, best_of_sets: playoff_best_of_sets || best_of_sets, **playoff_game_settings }
  end

  def playoff_match_settings_for_entries(entries_count, bracket: nil)
    role = if bracket == "final" || entries_count == 2
      :final
    elsif entries_count == 4
      :semifinal
    end

    playoff_match_settings(round_role: role)
  end
end
