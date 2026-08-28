module TournamentInitialization
  extend ActiveSupport::Concern

  included do
    before_validation :assign_defaults
    before_validation :ensure_tokens
  end

  private

  def assign_defaults
    self.visibility = if owner_user.present?
      "participant_only"
    elsif visibility.blank?
      "public_guest"
    else
      visibility
    end
    self.playoff_mode = "single_elimination" if playoff_mode.blank?
    self.seeding_mode = "auto" if seeding_mode.blank?
    self.status = "draft" if status.blank?
    self.playoff_best_of_legs ||= best_of_legs
    self.playoff_best_of_sets ||= best_of_sets
    self.semifinal_best_of_legs ||= playoff_best_of_legs || best_of_legs
    self.final_best_of_legs ||= playoff_best_of_legs || best_of_legs
    self.playoff_starting_score ||= starting_score
    self.playoff_double_in = double_in if playoff_double_in.nil?
    self.playoff_double_out = double_out if playoff_double_out.nil?
  end

  def ensure_tokens
    self.share_token ||= SecureRandom.hex(8)
    self.admin_token ||= SecureRandom.hex(16)
    self.join_token ||= SecureRandom.hex(6)
  end
end
