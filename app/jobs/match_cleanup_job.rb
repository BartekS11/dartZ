class MatchCleanupJob < ApplicationJob
  queue_as :default

  GUEST_RETENTION = 72.hours
  USER_RETENTION  = 1.year

  def perform
    stale_ids = stale_guest_match_ids + stale_user_match_ids
    stale_ids.uniq!

    Rails.logger.info "MatchCleanupJob: found #{stale_ids.size} stale matches"

    deleted_count = 0

    Match.where(id: stale_ids).find_each do |match|
      match.destroy!
      deleted_count += 1
    end

    Rails.logger.info "MatchCleanupJob: deleted #{deleted_count} stale matches"
    deleted_count
  end

  private

  def stale_guest_match_ids
    Match
      .where(updated_at: ..GUEST_RETENTION.ago)
      .where.not(id: user_backed_match_ids)
      .pluck(:id)
  end

  def stale_user_match_ids
    Match
      .where(id: user_backed_match_ids)
      .where(updated_at: ..USER_RETENTION.ago)
      .pluck(:id)
  end

  def user_backed_match_ids
    @user_backed_match_ids ||= Match
      .joins(:players)
      .where.not(players: { user_id: nil })
      .distinct
      .pluck(:id)
  end
end
