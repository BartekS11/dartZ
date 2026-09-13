class StatsController < ApplicationController
  before_action :require_authentication
  before_action -> { require_roadmap_feature!(:advanced_stats) }, only: :advanced

  def index
    @dashboard = MatchStatsDashboard.new(user: Current.user, params: stats_params)
    @summary = @dashboard.summary
    @chart_data = @dashboard.chart_data
    @opponents = @dashboard.opponents
    @dart_setups = @dashboard.dart_setups
  end

  def advanced
    @dashboard = AdvancedMatchStats.new(user: Current.user, filters: AdvancedStatsFilters.new(params).to_h)
    @summary = @dashboard.summary
    @trends = @dashboard.trends
    @distribution = @dashboard.distribution
    @checkouts = @dashboard.checkouts
    @head_to_head = @dashboard.head_to_head
    @leg_performance = @dashboard.leg_performance.first(20)
    @set_performance = @dashboard.set_performance.first(20)
    @coverage = @dashboard.coverage
    @training_stats = TrainingStats.new(user: Current.user).summary.select { |row| TrainingSession::EXPANDED_MODES.include?(row[:mode]) }

    filter_options = AdvancedMatchStats.new(user: Current.user)
    @opponents = filter_options.opponents
    @dart_setups = filter_options.dart_setups
  rescue Api::V1::RequestParameters::InvalidParameter => error
    redirect_to advanced_stats_path, alert: error.message
  end

  private

  def stats_params
    params.permit(:from, :to, :starting_score, :opponent, :opponent_type, :match_source, :dart_setup)
  end
end
