class BotMatchAllowance
  FREE_CREDIT_LIMIT = 40
  WINDOW = 7.days
  LEG_CHUNK_SIZE = 5.0

  attr_reader :user, :now

  def initialize(user, now: Time.current)
    @user = user
    @now = now
  end

  def unlimited?
    user&.premium_access?
  end

  def limit
    FREE_CREDIT_LIMIT
  end

  def used
    return 0 if unlimited? || user.blank?

    matches_in_window.pluck(:best_of_legs).sum { |best_of_legs| self.class.cost_for(best_of_legs: best_of_legs) }
  end

  def remaining
    return nil if unlimited?

    [ limit - used, 0 ].max
  end

  def allowed?(best_of_legs:)
    return true if unlimited?

    cost_for(best_of_legs: best_of_legs) <= remaining
  end

  def cost_for(best_of_legs:)
    self.class.cost_for(best_of_legs: best_of_legs)
  end

  def self.cost_for(best_of_legs:)
    (best_of_legs.to_i.clamp(1, 99) / LEG_CHUNK_SIZE).ceil
  end

  private

  def matches_in_window
    Match
      .where(id: Player.where(user_id: user.id).select(:match_id))
      .where(id: Player.where(bot: true).select(:match_id))
      .where(created_at: window_start..now)
  end

  def window_start
    now - WINDOW
  end
end
