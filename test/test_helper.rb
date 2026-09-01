ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
ActiveRecord.maintain_test_schema = false if ENV["RUN_E2E"] == "true"
require "rails/test_help"
require "mocha/minitest"

module RackTestSignedCookies
  def signed
    request = ActionDispatch::Request.empty
    Rails.application.env_config.each do |key, value|
      request.env[key] = value if key.to_s.start_with?("action_dispatch.")
    end
    ActionDispatch::Cookies::CookieJar.build(request, to_hash).signed
  end
end

Rack::Test::CookieJar.include(RackTestSignedCookies) unless Rack::Test::CookieJar.method_defined?(:signed)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all

    def create_user(email, password: "password")
      User.create!(
        email_address: email,
        password: password,
        password_confirmation: password
      )
    end
  end
end

class ActionDispatch::IntegrationTest
  def login_as(user, password: "password")
    post session_path, params: {
      email_address: user.email_address,
      password: password
    }
  end
end
