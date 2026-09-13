module Api
  module V1
    class TrainingSessionSerializer
      def initialize(session)
        @session = session
      end

      def as_json(*)
        {
          id: session.public_id,
          mode: session.mode,
          status: session.status,
          configuration: session.configuration,
          current_target: session.current_target,
          progress: session.session_progress,
          summary: session.summary,
          timestamps: {
            started_at: session.started_at&.iso8601,
            completed_at: session.completed_at&.iso8601,
            abandoned_at: session.abandoned_at&.iso8601,
            updated_at: session.updated_at.iso8601
          },
          allowed_actions: {
            submit_attempt: session.active?,
            complete: session.active? && session.expanded_mode? && session.mode_definition.manually_completable?,
            abandon: session.active?
          }
        }
      end

      private

      attr_reader :session
    end
  end
end
