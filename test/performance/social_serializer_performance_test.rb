require "test_helper"

class SocialSerializerPerformanceTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_PERFORMANCE_TESTS=1 to run performance tests" unless ENV["RUN_PERFORMANCE_TESTS"] == "1"
  end

  test "public user context query count stays fixed as a page grows" do
    viewer = create_user("social-performance-viewer@example.com")
    users = 100.times.map do |index|
      user = create_user("social-performance-#{index}@example.com")
      if index.even?
        Friendship.create_between!(viewer, user)
      else
        FriendRequest.create!(requester: viewer, recipient: user)
      end
      user
    end

    small = measure(viewer, users.first(1))
    large = measure(viewer, users)

    puts "SocialSerializer 1 user: #{small[:elapsed].round(4)}s, #{small[:queries]} queries"
    puts "SocialSerializer 100 users: #{large[:elapsed].round(4)}s, #{large[:queries]} queries"

    assert_operator small[:queries], :<=, 2
    assert_equal small[:queries], large[:queries]
    assert_operator large[:elapsed], :<, 1.0
  end

  private

  def measure(viewer, users)
    queries = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached]
      next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)

      queries += 1
    end

    elapsed = nil
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        serializer = Api::V1::SocialSerializer.new(viewer: viewer, users: users)
        users.each { |user| serializer.user(user) }
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    { elapsed:, queries: }
  end
end
