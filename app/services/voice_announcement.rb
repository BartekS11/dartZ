class VoiceAnnouncement
  SOUNDS_BY_TOTAL = {
    0 => "no-score",
    26 => "26",
    41 => "41",
    45 => "45",
    100 => "100",
    180 => "180"
  }.freeze
  SOUND_KEYS = SOUNDS_BY_TOTAL.values.freeze
  FILES_BY_SOUND = SOUND_KEYS.index_with { |sound| "#{sound}.mp3" }.freeze

  class << self
    def authorized_user?(user)
      user.present? && user.email_address.to_s.casecmp?(authorized_email)
    end

    def broadcast_for(turn:, total:)
      sound = SOUNDS_BY_TOTAL[total]
      return unless sound

      Turbo::StreamsChannel.broadcast_append_to(
        "match_#{turn.leg.match_id}",
        target: "voice-announcements",
        partial: "voice_announcements/announcement",
        locals: { sound: sound, event_id: turn.public_id }
      )
    end

    def path_for(sound)
      filename = FILES_BY_SOUND[sound]
      return unless filename

      Rails.root.join("private", "voice_announcements", filename)
    end

    private

    def authorized_email
      ENV.fetch("VOICE_ANNOUNCEMENT_EMAIL", "test@example.com").to_s.strip
    end
  end
end
