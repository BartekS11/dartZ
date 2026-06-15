ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
