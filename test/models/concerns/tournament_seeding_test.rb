require "test_helper"

class TournamentSeedingTest < ActiveSupport::TestCase
  test "building entries assigns consecutive seeds and alternating groups without saving" do
    tournament = Tournament.new(title: "Groups", format_type: "groups", group_count: 2)

    assert_no_difference("TournamentEntry.count") do
      tournament.build_seeded_entries(%w[Alice Bob Cara Dan])
    end

    assert_equal %w[Alice Bob Cara Dan], tournament.entries.map(&:name)
    assert_equal [ 1, 2, 3, 4 ], tournament.entries.map(&:seed)
    assert_equal %w[A B A B], tournament.entries.map(&:group_name)
    tournament.save!
    assert_equal 4, tournament.entries.reload.count
  end

  test "small groups clamp group count and non-group formats have no groups" do
    tournament = Tournament.new(format_type: "groups", group_count: 20)
    tournament.build_seeded_entries(%w[Alice Bob])
    assert_equal %w[A A], tournament.entries.map(&:group_name)

    tournament = Tournament.new(format_type: "swiss")
    tournament.build_seeded_entries(%w[Alice Bob])
    assert_equal [ nil, nil ], tournament.entries.map(&:group_name)
  end

  test "reseed follows creation order rather than previous seed or name" do
    tournament = Tournament.create!(title: "Seeds", format_type: "groups")
    first = tournament.entries.create!(name: "Zoe", seed: 8)
    second = tournament.entries.create!(name: "Alice", seed: 2)

    tournament.reseed_entries

    assert_equal 1, first.reload.seed
    assert_equal 2, second.reload.seed
  end

  test "preview groups follow seed then name and do not generate rounds" do
    tournament = Tournament.create!(title: "Preview", format_type: "groups", group_count: 2)
    [ [ "Zoe", nil ], [ "Cara", 2 ], [ "Bob", 1 ], [ "Alice", 1 ] ].each do |name, seed|
      tournament.entries.create!(name: name, seed: seed, group_name: "Z")
    end

    assert_no_difference("TournamentRound.count") { tournament.assign_preview_groups }

    assert_equal({ "Alice" => "A", "Bob" => "B", "Cara" => "A", "Zoe" => "B" }, tournament.entries.pluck(:name, :group_name).to_h)
    assert_equal "draft", tournament.reload.status
  end

  test "preview assignment leaves non-group entries untouched" do
    tournament = Tournament.create!(title: "Swiss", format_type: "swiss")
    entry = tournament.entries.create!(name: "Alice", group_name: "Custom")

    tournament.assign_preview_groups

    assert_equal "Custom", entry.reload.group_name
  end
end
