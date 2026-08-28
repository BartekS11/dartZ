module HasDurationDisplay
  extend ActiveSupport::Concern

  def duration_minutes
    return nil unless finished?

    ((finished_at - created_at) / 60).round
  end

  def duration_display
    return nil unless finished?

    total = (finished_at - created_at).to_i
    mins  = total / 60
    secs  = total % 60
    format("%d:%02d", mins, secs)
  end
end
