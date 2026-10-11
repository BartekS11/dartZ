class TrainingRecommendations
  MINIMUM_SESSIONS = 10

  def initialize(user:, stats: TrainingStats.new(user:).summary)
    @user = user
    @stats = stats
  end

  def call
    meaningful = stats.select { |stat| stat[:completed_count] >= MINIMUM_SESSIONS && stat[:delta].present? }
    return { status: :insufficient_data, recommendations: [] } if meaningful.empty?

    declining = meaningful.select { |stat| stat[:trend] == "declined" }
    return { status: :on_track, recommendations: [] } if declining.empty?

    {
      status: :recommendations,
      recommendations: declining.sort_by { |stat| -stat[:delta] }.first(2).map do |stat|
        {
          mode: stat[:mode],
          sample_size: stat[:completed_count],
          delta: stat[:delta],
          reason: :recent_average_increased
        }
      end
    }
  end

  private

  attr_reader :user, :stats
end
