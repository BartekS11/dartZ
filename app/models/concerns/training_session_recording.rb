module TrainingSessionRecording
  extend ActiveSupport::Concern

  def record_hit!(misses_before_hit: 0)
    return false unless active?

    return record_checkout_attempt!(hit: true, misses_count: misses_before_hit) if checkout_randomizer_mode?

    misses_count = normalize_count(misses_before_hit)
    stats = append_target_stat(hit: true, misses_count: misses_count, darts_count: misses_count + 1)
    next_index = current_target_index + 1
    attrs = {
      target_stats: stats,
      misses: misses + misses_count,
      hits: hits + 1,
      total_darts: total_darts + misses_count + 1,
      current_target_index: next_index
    }

    if next_index >= targets.length
      attrs[:status] = "completed"
      attrs[:completed_at] = Time.current
    end

    update!(attrs).tap do |saved|
      TrainingSessionPracticePlanProgressor.call(self) if saved && completed?
    end
  end

  def record_no_hit!(misses_count: 1)
    return false unless active?

    return record_checkout_attempt!(hit: false, misses_count: misses_count) if checkout_randomizer_mode?

    count = [ normalize_count(misses_count), 1 ].max
    update!(
      target_stats: append_target_stat(hit: false, misses_count: count, darts_count: count),
      misses: misses + count,
      total_darts: total_darts + count
    )
  end

  private

  def record_checkout_attempt!(hit:, misses_count:)
    count = normalize_count(misses_count)
    count = [ count, 1 ].max unless hit
    darts_count = hit ? count + 1 : count
    update!(
      target_stats: append_target_stat(hit: hit, misses_count: count, darts_count: darts_count),
      misses: misses + count,
      hits: hits + (hit ? 1 : 0),
      total_darts: total_darts + darts_count,
      current_target_index: random_checkout_score
    )
  end

  def normalize_count(value)
    Integer(value.presence || 0).clamp(0, 99)
  rescue ArgumentError, TypeError
    0
  end

  def append_target_stat(hit:, misses_count:, darts_count:)
    target = current_target || targets.last
    target_stats + [
      {
        "target" => target.fetch("key"),
        "label" => target.fetch("label"),
        "hit" => hit,
        "misses" => misses_count,
        "darts" => darts_count,
        "recorded_at" => Time.current.iso8601
      }
    ]
  end
end
