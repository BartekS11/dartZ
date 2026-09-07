module MatchesHelper
  def player_display_swap_allowed?(match)
    match.player_display_swappable_by?(user: Current.user)
  end
end
