module MatchLifecycle
  extend ActiveSupport::Concern

  def finished?
    finished_at.present?
  end

  def finish!
    update!(finished_at: Time.current)
  end
end
