# frozen_string_literal: true

require "e2e_helper"

class ContainerBootTest < E2EIntegrationTest
  test "boots Rails against isolated Testcontainers PostgreSQL" do
    assert ENV["DATABASE_URL"].present?
    assert ActiveRecord::Base.connection.active?
    assert_equal 0, Match.count
  end
end
