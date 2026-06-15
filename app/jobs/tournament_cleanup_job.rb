class TournamentCleanupJob < ApplicationJob
  queue_as :default

  GUEST_RETENTION = 3.months
  USER_RETENTION  = 1.year

  def perform
    stale_ids = stale_guest_tournament_ids + stale_user_tournament_ids
    stale_ids.uniq!

    Rails.logger.info "TournamentCleanupJob: found #{stale_ids.size} stale tournaments"

    deleted_count = 0

    Tournament.where(id: stale_ids).find_each do |tournament|
      tournament.destroy!
      deleted_count += 1
    end

    Rails.logger.info "TournamentCleanupJob: deleted #{deleted_count} stale tournaments"
    deleted_count
  end

  private

  def stale_guest_tournament_ids
    Tournament
      .where(owner_user_id: nil)
      .where(updated_at: ..GUEST_RETENTION.ago)
      .pluck(:id)
  end

  def stale_user_tournament_ids
    Tournament
      .where.not(owner_user_id: nil)
      .where(updated_at: ..USER_RETENTION.ago)
      .pluck(:id)
  end
end
