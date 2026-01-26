module TurnFlow
  extend ActiveSupport::Concern

  def complete_turn!
    return if completed?

    update!(completed_at: Time.current)
    leg.start_next_turn!
  end

  def completed?
    completed_at.present?
  end
end
