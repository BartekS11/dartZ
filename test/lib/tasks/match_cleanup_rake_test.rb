require "test_helper"
require "rake"

class MatchCleanupRakeTest < ActiveSupport::TestCase
  setup do
    @original_rake = Rake.application
    Rake.application = Rake::Application.new
    load Rails.root.join("Rakefile").to_s
    Rake::Task.define_task(:environment)
  end

  teardown do
    Rake.application = @original_rake
  end

  test "cleanup:match_cleanup enqueues MatchCleanupJob" do
    called = false
    original = MatchCleanupJob.method(:perform_later)
    MatchCleanupJob.define_singleton_method(:perform_later) { called = true }

    Rake::Task["cleanup:match_cleanup"].invoke

    assert called
  ensure
    MatchCleanupJob.define_singleton_method(:perform_later, original)
  end

  test "cleanup:match_cleanup re-raises enqueue errors" do
    original = MatchCleanupJob.method(:perform_later)
    MatchCleanupJob.define_singleton_method(:perform_later) { raise StandardError, "boom" }

    assert_raises(StandardError) do
      Rake::Task["cleanup:match_cleanup"].invoke
    end
  ensure
    MatchCleanupJob.define_singleton_method(:perform_later, original)
  end
end
