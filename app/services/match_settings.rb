class MatchSettings
  attr_reader :best_of_legs, :best_of_sets, :starting_score, :double_in, :double_out

  def self.from_params(params, double_out_default: true)
    new(
      best_of_legs: params[:best_of_legs].to_i.clamp(1, 99),
      best_of_sets: params[:best_of_sets].to_i.clamp(1, 99),
      starting_score: permitted_starting_score(params[:starting_score]),
      double_in: truthy_param?(params, :double_in),
      double_out: truthy_param?(params, :double_out, default: double_out_default)
    )
  end

  def self.from_tournament_match(tournament_match)
    new(
      best_of_legs: tournament_match.best_of_legs,
      best_of_sets: tournament_match.best_of_sets,
      starting_score: tournament_match.starting_score,
      double_in: tournament_match.double_in,
      double_out: tournament_match.double_out
    )
  end

  def initialize(best_of_legs:, best_of_sets:, starting_score:, double_in:, double_out:)
    @best_of_legs = best_of_legs
    @best_of_sets = best_of_sets
    @starting_score = starting_score
    @double_in = double_in
    @double_out = double_out
  end

  def to_h
    {
      best_of_legs: best_of_legs,
      best_of_sets: best_of_sets,
      starting_score: starting_score,
      double_in: double_in,
      double_out: double_out
    }
  end

  def self.permitted_starting_score(value)
    score = value.to_i
    Match::X01_STARTING_SCORES.include?(score) ? score : 501
  end
  private_class_method :permitted_starting_score

  def self.truthy_param?(params, key, default: false)
    return default unless params.key?(key)

    ActiveModel::Type::Boolean.new.cast(params[key])
  end
  private_class_method :truthy_param?
end
