require "test_helper"

class Social::FriendshipConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @users = [
      create_user("friend-race-a-#{SecureRandom.hex(6)}@example.com"),
      create_user("friend-race-b-#{SecureRandom.hex(6)}@example.com")
    ]
    @users.last.update!(friend_request_policy: "anyone")
  end

  teardown do
    @users.each { |user| user.destroy! if user.persisted? }
  end

  test "concurrent duplicate sends resolve to one pending request" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << Social::FriendshipManager.send_request(actor: @users.first, target: @users.last)
        rescue StandardError => error
          results << error
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    returned = 2.times.map { results.pop }

    assert returned.none?(Exception), returned.map(&:inspect).join("\n")
    assert_equal 1, FriendRequest.pending.where(pair_key: [ @users.first.id, @users.last.id ].sort.join(":")).count
    assert_equal 1, returned.map(&:id).uniq.size
  end
end
