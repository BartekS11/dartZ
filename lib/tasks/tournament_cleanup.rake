namespace :cleanup do
  desc "Queue tournament cleanup for stale guest and logged-in tournaments"
  task tournament_cleanup: :environment do
    Rails.logger.info "Queueing TournamentCleanupJob"

    TournamentCleanupJob.perform_later
    puts "✅ TournamentCleanupJob queued"
  rescue => e
    Rails.logger.error "Failed to queue TournamentCleanupJob: #{e.class}: #{e.message}"
    warn "❌ Failed to queue TournamentCleanupJob"
    raise
  end
end
