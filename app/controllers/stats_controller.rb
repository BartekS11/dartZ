class StatsController < ApplicationController
  before_action :require_authentication

  def index
    @dashboard = MatchStatsDashboard.new(user: Current.user, params: stats_params)
    @summary = @dashboard.summary
    @chart_data = @dashboard.chart_data
    @opponents = @dashboard.opponents
    @dart_setups = @dashboard.dart_setups
  end

  private

  def stats_params
    params.permit(:from, :to, :starting_score, :opponent, :opponent_type, :match_source, :dart_setup)
  end
end
