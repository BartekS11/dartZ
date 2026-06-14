namespace :cleanup do
  desc "Queue match cleanup for stale guest and user-backed matches"
  task match_cleanup: :environment do
    Rails.logger.info "Queueing MatchCleanupJob"

    MatchCleanupJob.perform_later
    puts "✅ MatchCleanupJob queued"
  rescue => e
    Rails.logger.error "Failed to queue MatchCleanupJob: #{e.class}: #{e.message}"
    warn "❌ Failed to queue MatchCleanupJob"
    raise
  end
end
