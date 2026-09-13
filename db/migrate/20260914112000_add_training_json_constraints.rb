class AddTrainingJsonConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :training_sessions, "jsonb_typeof(configuration) = 'object'", name: "training_sessions_configuration_object"
    add_check_constraint :training_sessions, "jsonb_typeof(state) = 'object'", name: "training_sessions_state_object"
    add_check_constraint :training_drills, "jsonb_typeof(configuration) = 'object'", name: "training_drills_configuration_object"
    add_check_constraint :training_attempts, "jsonb_typeof(result) = 'object'", name: "training_attempts_result_object"
    add_check_constraint :training_attempts, "jsonb_typeof(response) = 'object'", name: "training_attempts_response_object"
  end
end
