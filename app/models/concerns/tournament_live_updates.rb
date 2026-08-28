module TournamentLiveUpdates
  extend ActiveSupport::Concern

  def sync_from_linked_matches!
    tournament_matches.includes(:linked_match).find_each(&:sync_from_linked_match!)
    TournamentProgressor.new(self).call
  end

  def broadcast_live_update!(can_admin: false, admin_token: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :live ],
      target: "tournament-live-panels",
      partial: "tournaments/live_panels",
      locals: { tournament: self, can_admin: can_admin, admin_token: admin_token }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :live ],
      target: "tournament-live-board",
      partial: "tournaments/live_board",
      locals: { tournament: self, can_admin: can_admin, admin_token: admin_token }
    )
  end
end
