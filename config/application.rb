require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DartZ
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails_api_master])
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.time_zone = "Warsaw"
    config.i18n.default_locale = :en
    config.i18n.available_locales = %i[en pl nl es]

    config.active_job.queue_adapter = :async

    boolean_type = ActiveModel::Type::Boolean.new
    config.x.api_v1_enabled = boolean_type.cast(ENV.fetch("API_V1_ENABLED", true))
    config.x.roadmap_features = {
      advanced_stats: boolean_type.cast(ENV.fetch("ADVANCED_STATS_ENABLED", false)),
      expanded_training: boolean_type.cast(ENV.fetch("EXPANDED_TRAINING_ENABLED", false)),
      friends: boolean_type.cast(ENV.fetch("FRIENDS_ENABLED", false)),
      web_push: boolean_type.cast(ENV.fetch("WEB_PUSH_ENABLED", false)),
      offline_scoring: boolean_type.cast(ENV.fetch("OFFLINE_SCORING_ENABLED", false))
    }.freeze

    configured_admin_path = ENV["ADMIN_PATH"].to_s.strip.presence
    raise "ADMIN_PATH is required in production" if Rails.env.production? && configured_admin_path.blank?

    admin_path = configured_admin_path || "ops-console-local"
    unless admin_path.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{11,}\z/)
      raise "ADMIN_PATH must be one URL-safe path segment with at least 12 characters"
    end
    config.x.admin_path = admin_path

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
