require "test_helper"
require "rake"

class TournamentCleanupRakeTest < ActiveSupport::TestCase
  setup do
    @original_rake = Rake.application
    Rake.application = Rake::Application.new
    load Rails.root.join("Rakefile").to_s
    Rake::Task.define_task(:environment)
  end

  teardown do
    Rake.application = @original_rake
  end

  test "cleanup:tournament_cleanup enqueues TournamentCleanupJob" do
    called = false
    original = TournamentCleanupJob.method(:perform_later)
    TournamentCleanupJob.define_singleton_method(:perform_later) { called = true }

    Rake::Task["cleanup:tournament_cleanup"].invoke

    assert called
  ensure
    TournamentCleanupJob.define_singleton_method(:perform_later, original)
  end

  test "cleanup:tournament_cleanup re-raises enqueue errors" do
    original = TournamentCleanupJob.method(:perform_later)
    TournamentCleanupJob.define_singleton_method(:perform_later) { raise StandardError, "boom" }

    assert_raises(StandardError) do
      Rake::Task["cleanup:tournament_cleanup"].invoke
    end
  ensure
    TournamentCleanupJob.define_singleton_method(:perform_later, original)
  end
end
