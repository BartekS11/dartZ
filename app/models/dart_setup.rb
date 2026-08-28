require "digest"

class DartSetup < ApplicationRecord
  MANUFACTURER_LABELS = {
    "winmau" => "WINMAU",
    "target" => "Target",
    "unicorn" => "Unicorn",
    "harrows" => "Harrows",
    "red_dragon" => "Red Dragon",
    "mission" => "Mission",
    "shot" => "Shot Darts",
    "one80" => "One80",
    "bulls" => "Bull's",
    "cosmo_darts" => "Cosmo Darts",
    "loxley" => "Loxley",
    "target_japan" => "Target Japan",
    "other" => "Other"
  }.freeze
  MANUFACTURERS = MANUFACTURER_LABELS.keys.freeze
  SHAFT_TYPES = %w[nylon aluminum carbon titanium hybrid other].freeze

  include DartSetupSnapshot

  belongs_to :user

  validates :manufacturer, presence: true, inclusion: { in: MANUFACTURERS }
  validates :weight_g, presence: true, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 60 }
  validates :shaft_type, presence: true, inclusion: { in: SHAFT_TYPES }
  validates :shaft_length_mm, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 20, less_than_or_equal_to: 70 }
  validates :point_length_mm, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 20, less_than_or_equal_to: 60 }
end
