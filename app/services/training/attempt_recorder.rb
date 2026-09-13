module Training
  class AttemptRecorder
    def self.call(session:, idempotency_key:, result:)
      new(session, idempotency_key, result).call
    end

    def initialize(session, idempotency_key, result)
      @session = session
      @idempotency_key = idempotency_key.to_s
      @result = (result || {}).to_h.stringify_keys
    end

    def call
      session.with_lock do
        existing = session.training_attempts.find_by(idempotency_key: idempotency_key)
        return existing if existing
        raise InvalidAttempt.new("completed or abandoned sessions cannot be updated", details: { conflict: true }) unless session.active?

        target = session.current_target
        raise InvalidAttempt, "session has no remaining target" unless target

        outcome = session.mode_definition.apply(session, result)
        attempt = session.training_attempts.create!(
          idempotency_key: idempotency_key,
          sequence: session.training_attempts.size + 1,
          target: target.fetch("key"),
          result: result,
          darts: outcome.fetch(:darts),
          hits: outcome.fetch(:hits),
          successful: outcome.fetch(:successful)
        )
        update_session!(outcome, target)
        attempt
      end
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidAttempt.new(error.record.errors.full_messages.to_sentence, details: error.record.errors.to_hash)
    end

    private

    attr_reader :session, :idempotency_key, :result

    def update_session!(outcome, target)
      attrs = {
        state: outcome.fetch(:state),
        score: outcome.fetch(:score, session.score),
        total_darts: session.total_darts + outcome.fetch(:darts),
        hits: session.hits + outcome.fetch(:hits),
        misses: session.misses + outcome.fetch(:darts) - outcome.fetch(:hits),
        current_target_index: outcome.fetch(:state).fetch("position", 0),
        target_stats: session.target_stats + [ {
          "target" => target.fetch("key"), "label" => target.fetch("label"),
          "hit" => outcome.fetch(:successful), "hits" => outcome.fetch(:hits),
          "misses" => outcome.fetch(:darts) - outcome.fetch(:hits), "darts" => outcome.fetch(:darts),
          "recorded_at" => Time.current.iso8601
        } ]
      }
      if outcome.fetch(:complete)
        attrs.merge!(status: "completed", completed_at: Time.current)
      end
      session.update!(attrs)
      TrainingSessionPracticePlanProgressor.call(session) if session.completed?
    end
  end
end
