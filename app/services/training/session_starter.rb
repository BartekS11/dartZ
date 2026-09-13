module Training
  class SessionStarter
    def self.call(user:, mode:, configuration: {})
      values = (configuration || {}).to_h.stringify_keys
      drill_name = values.delete("name") if mode.to_s == "custom_targets"
      definition = ModeRegistry.fetch(mode, values)
      if drill_name.present?
        drill = user.training_drills.find_or_initialize_by(name: drill_name.to_s.strip)
        drill.configuration = definition.configuration
        drill.save!
        definition.configuration["drill_id"] = drill.public_id
      end
      user.training_sessions.create!(
        mode: mode,
        configuration: definition.configuration,
        state: definition.initial_state,
        score: definition.initial_score
      )
    end
  end
end
