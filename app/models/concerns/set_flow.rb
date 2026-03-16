module SetFlow
  extend ActiveSupport::Concern

  def on_leg_finished!(winner)
    won = legs_won_by(winner)

    if won >= legs_needed_to_win
      finish!(winner)
    else
      start_next_leg!
    end
  end
end
