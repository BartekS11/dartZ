class AdvancedStatsFilters
  MATCH_SOURCES = %w[casual tournament].freeze
  BOOLEAN_VALUES = %w[true false 1 0].freeze
  DART_SETUP_ID_FORMAT = /\A[0-9a-f]{16}\z/

  def initialize(params)
    @params = params
  end

  def to_h
    date_range = Api::V1::RequestParameters.new(params).date_range

    {
      from: date_range.from,
      to: date_range.to,
      starting_score: starting_score,
      opponent_id: optional_value(:opponent_id, format: Player.public_id_format),
      match_source: match_source,
      dart_setup_id: optional_value(:dart_setup_id, format: DART_SETUP_ID_FORMAT),
      double_in: boolean_value(:double_in),
      double_out: boolean_value(:double_out)
    }.compact
  end

  private

  attr_reader :params

  def starting_score
    value = params[:starting_score]
    return if value.blank?

    score = Integer(value.to_s, 10, exception: false)
    return score if Match::X01_STARTING_SCORES.include?(score)

    invalid!(:starting_score, "starting_score is not supported")
  end

  def match_source
    value = params[:match_source]
    return if value.blank?
    return value if MATCH_SOURCES.include?(value)

    invalid!(:match_source, "match_source must be casual or tournament")
  end

  def boolean_value(key)
    value = params[key]
    return if value.blank?
    return value if BOOLEAN_VALUES.include?(value.to_s)

    invalid!(key, "#{key} must be true or false")
  end

  def optional_value(key, format:)
    value = params[key]
    return if value.blank?
    return value if value.to_s.match?(format)

    invalid!(key, "#{key} has an invalid format")
  end

  def invalid!(key, message)
    raise Api::V1::RequestParameters::InvalidParameter.new(key, message)
  end
end
