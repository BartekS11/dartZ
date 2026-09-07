class Match < ApplicationRecord
  X01_STARTING_SCORES = X01GameSettings::STARTING_SCORES

  before_destroy :destroy_direct_legs

  include HasPublicId
  public_id_prefix "m_"

  include X01GameSettings
  include MatchLifecycle
  include MatchInvitable
  include MatchIdentifiable
  include MatchLegManagement
  include MatchPlayerOrdering
  include HasThrowHistory
  include HasUndoSupport

  has_many :players,  dependent: :destroy
  has_many :match_sets, dependent: :destroy, class_name: "MatchSet"
  has_many :legs,     through: :match_sets
  has_many :turns,    through: :legs
  has_many :throws,   through: :turns

  validates :match_identifier, uniqueness: true, allow_blank: true
  validates :guest_token, uniqueness: true, allow_blank: true
  validates :best_of_legs, :best_of_sets, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :starting_score, inclusion: { in: X01_STARTING_SCORES }
  validates :double_in, :double_out, inclusion: { in: [ true, false ] }
  validates :invite_token, uniqueness: true, allow_blank: true
  validates :starting_player_position, inclusion: { in: [ 1, 2 ] }

  private

  def destroy_direct_legs
    Leg.where(match_id: id).find_each(&:destroy!)
  end
end
