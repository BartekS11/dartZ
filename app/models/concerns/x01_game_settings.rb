module X01GameSettings
  extend ActiveSupport::Concern

  STARTING_SCORES = [ 101, 201, 301, 401, 501, 601, 701 ].freeze

  def game_mode_labels
    labels = [ starting_score.to_s ]
    labels << "Double in" if double_in?
    labels << "Double out" if double_out?
    labels
  end

  def game_settings
    { starting_score: starting_score, double_in: double_in, double_out: double_out }
  end
end
