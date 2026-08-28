module TournamentStandings
  extend ActiveSupport::Concern

  def standings
    entries.to_a.sort_by do |entry|
      [ -entry.wins, -entry.leg_difference, -(swiss_stage_enabled? ? entry.buchholz.to_f : entry.points), -entry.points, entry.name.downcase ]
    end
  end

  def group_names
    entries.where.not(group_name: [ nil, "" ]).distinct.order(:group_name).pluck(:group_name)
  end

  def standings_for_group(group_name)
    entries.where(group_name: group_name).to_a.sort_by do |entry|
      [ -entry.wins, -entry.leg_difference, -entry.points, entry.name.downcase ]
    end
  end

  def qualifiers_per_group_value
    qualifiers_per_group.presence || begin
      groups = [ group_names.size, 1 ].max
      count = playoff_qualifier_count.presence || groups * 2
      [ (count.to_f / groups).ceil, 1 ].max
    end
  end
end
