module Api
  module V1
    class TrainingSessionsController < BaseController
      before_action -> { require_api_roadmap_feature!(:expanded_training) }
      before_action :set_session, only: %i[show create_attempt complete abandon]

      rescue_from Training::InvalidAttempt, with: :render_training_error

      def modes
        render json: { data: Training::ModeRegistry.definitions }
      end

      def index
        scope = current_api_user.training_sessions.where(mode: TrainingSession::EXPANDED_MODES).order(created_at: :desc, public_id: :desc)
        scope = filter_scope(scope)
        sessions, pagination = paginate(scope)
        render json: { data: sessions.map { |session| serialize(session) }, pagination: pagination }
      end

      def create
        session = Training::SessionStarter.call(
          user: current_api_user,
          mode: params.require(:mode),
          configuration: params[:configuration]&.to_unsafe_h || {}
        )
        render json: { data: serialize(session) }, status: :created
      rescue ActionController::ParameterMissing => error
        render_api_error(code: "validation_failed", message: error.message, status: :unprocessable_entity)
      end

      def show
        render json: { data: serialize(@training_session) }
      end

      def create_attempt
        attempt = Training::AttemptRecorder.call(
          session: @training_session,
          idempotency_key: params.require(:idempotency_key),
          result: params.require(:result).permit(:hits, :score, :darts, :checkout).to_h
        )
        @training_session.reload
        body = attempt.response.presence || { data: serialize(@training_session), attempt: serialize_attempt(attempt) }
        attempt.update!(response: body) if attempt.response.blank?
        render json: body, status: :created
      rescue ActionController::ParameterMissing => error
        render_api_error(code: "validation_failed", message: error.message, status: :unprocessable_entity)
      end

      def complete
        unless @training_session.mode_definition.manually_completable?
          raise Training::InvalidAttempt, "this mode completes automatically"
        end
        raise Training::InvalidAttempt.new("session is already finished", details: { conflict: true }) unless @training_session.complete!

        render json: { data: serialize(@training_session) }
      end

      def abandon
        raise Training::InvalidAttempt.new("session is already finished", details: { conflict: true }) unless @training_session.abandon!

        render json: { data: serialize(@training_session) }
      end

      private

      def set_session
        @training_session = current_api_user.training_sessions.where(mode: TrainingSession::EXPANDED_MODES).find_by!(public_id: params[:id])
      end

      def filter_scope(scope)
        if params[:mode].present?
          raise Training::InvalidAttempt, "mode is invalid" unless TrainingSession::EXPANDED_MODES.include?(params[:mode])
          scope = scope.where(mode: params[:mode])
        end
        if params[:status].present?
          raise Training::InvalidAttempt, "status is invalid" unless TrainingSession::STATUSES.include?(params[:status])
          scope = scope.where(status: params[:status])
        end
        range = api_date_range
        scope = scope.where(created_at: range.from.beginning_of_day..) if range.from
        scope = scope.where(created_at: ..range.to.end_of_day) if range.to
        scope
      end

      def serialize(session)
        Api::V1::TrainingSessionSerializer.new(session).as_json
      end

      def serialize_attempt(attempt)
        { id: attempt.public_id, idempotency_key: attempt.idempotency_key, sequence: attempt.sequence,
          target: attempt.target, result: attempt.result, darts: attempt.darts, hits: attempt.hits,
          successful: attempt.successful, created_at: attempt.created_at.iso8601 }
      end

      def render_training_error(error)
        status = error.details[:conflict] ? :conflict : :unprocessable_entity
        code = error.details[:conflict] ? "conflict" : "validation_failed"
        render_api_error(code: code, message: error.message, status: status, details: error.details.except(:conflict))
      end
    end
  end
end
