class Player < ApplicationRecord
  has_many :leg_players, dependent: :destroy
  has_many :turns, dependent: :destroy
  has_many :legs, through: :leg_players

  belongs_to :user, optional: true
  belongs_to :match
  belongs_to :dart_setup, optional: true

  validates :name, presence: true, length: { maximum: 20 }
  validates :bot_level, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true

  def bot?
    bot == true
  end

  def guest?
    user_id.nil? && !bot?
  end

  def display_name
    return name if bot? || guest?
    user.display_name
  end

  def assign_dart_setup_snapshot!(setup)
    self.dart_setup = setup
    self.dart_setup_snapshot = setup.snapshot_attributes
    self.dart_setup_fingerprint = setup.fingerprint
  end

  def dart_setup_tracked?
    dart_setup_fingerprint.present? && dart_setup_snapshot.present?
  end

  def dart_setup_summary
    return nil unless dart_setup_tracked?

    snapshot = dart_setup_snapshot
    "#{snapshot['manufacturer_label'] || snapshot['manufacturer'].to_s.humanize} · #{snapshot['weight_g']}g · #{snapshot['shaft_type_label'] || snapshot['shaft_type'].to_s.humanize} · #{snapshot['shaft_length_mm']}mm shaft · #{snapshot['point_length_mm']}mm point"
  end
end
