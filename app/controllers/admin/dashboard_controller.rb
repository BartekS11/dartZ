module Admin
  class DashboardController < BaseController
    def show
      @user_count = User.count
      @tier_counts = User.group(Arel.sql("COALESCE(manual_tier_override, account_tier)")).count
      @match_count = Match.count
      @completed_match_count = Match.where.not(finished_at: nil).count
    end
  end
end
