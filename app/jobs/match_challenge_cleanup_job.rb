class MatchChallengeCleanupJob < ApplicationJob
  BATCH_SIZE = 500

  queue_as :default

  def perform
    total = 0
    loop do
      processed = expire_batch
      break if processed.zero?

      total += processed
    end
    total
  end

  private

  def expire_batch
    ApplicationRecord.transaction do
      challenges = MatchChallenge.pending.where(expires_at: ..Time.current)
        .order(:id).lock("FOR UPDATE SKIP LOCKED").limit(BATCH_SIZE).to_a
      next 0 if challenges.empty?

      now = Time.current
      match_ids = challenges.map(&:match_id)
      Match.where(id: match_ids, invite_joined_at: nil, invite_cancelled_at: nil)
        .where("invite_expires_at > ?", now)
        .update_all(invite_cancelled_at: now, updated_at: now)
      MatchChallenge.where(id: challenges.map(&:id))
        .update_all(status: "expired", resolved_at: now, updated_at: now)
    end
  end
end
