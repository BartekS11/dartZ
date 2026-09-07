module TournamentSeeding
  extend ActiveSupport::Concern

  def build_seeded_entries(names)
    count = effective_group_count(entries_count: names.size)
    names.each_with_index do |name, index|
      group_name = group_stage_enabled? ? TournamentGroupNaming.label(index % count) : nil
      entries.build(name: name, seed: index + 1, group_name: group_name)
    end
  end

  def reseed_entries
    entries.order(:created_at).each_with_index do |entry, index|
      entry.update!(seed: index + 1)
    end
  end

  def assign_preview_groups
    return unless group_stage_enabled?

    ordered_entries = entries.order(Arel.sql("COALESCE(seed, 999999), lower(name)"))
    count = effective_group_count
    ordered_entries.each_with_index do |entry, index|
      entry.update!(group_name: TournamentGroupNaming.label(index % count))
    end
  end
end
