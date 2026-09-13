module Api
  module V1
    class StatisticsController < BaseController
      before_action -> { require_api_roadmap_feature!(:advanced_stats) }

      def summary
        render json: {
          data: dashboard.summary.merge(
            coverage: dashboard.coverage,
            recent_legs: dashboard.leg_performance.first(20),
            recent_sets: dashboard.set_performance.first(20),
            training: expanded_training_summary
          )
        }
      end

      def trends
        render_collection(dashboard.trends)
      end

      def distribution
        render_collection(dashboard.distribution)
      end

      def checkouts
        render json: { data: dashboard.checkouts.merge(coverage: dashboard.coverage) }
      end

      def head_to_head
        render_collection(dashboard.head_to_head)
      end

      private

      def expanded_training_summary
        return [] unless Rails.configuration.x.roadmap_features[:expanded_training]

        TrainingStats.new(user: current_api_user).summary.select { |row| TrainingSession::EXPANDED_MODES.include?(row[:mode]) }
      end

      def dashboard
        @dashboard ||= AdvancedMatchStats.new(
          user: current_api_user,
          filters: AdvancedStatsFilters.new(params).to_h
        )
      end

      def render_collection(items)
        data, pagination = paginate_array(items)
        render json: { data: data, pagination: pagination }
      end
    end
  end
end
