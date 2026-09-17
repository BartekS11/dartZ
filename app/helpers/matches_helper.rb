module MatchesHelper
  def player_thrower_swap_visible?(match)
    match.player_thrower_swap_visible_by?(user: Current.user)
  end

  def player_thrower_swap_enabled?(match)
    player_thrower_swap_visible?(match) && match.player_thrower_swappable?
  end
end
