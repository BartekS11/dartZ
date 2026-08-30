# frozen_string_literal: true

require_relative "e2e_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium-webdriver"
require "action_dispatch/system_test_case"

Capybara.default_max_wait_time = ENV.fetch("CAPYBARA_WAIT", 5).to_i

Capybara.register_driver :container_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include E2ETestHelpers

  driven_by :container_headless_chrome

  setup do
    skip "Set RUN_E2E=true to run slow Testcontainers system tests" unless E2E_ENABLED
  end
end
