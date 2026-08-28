require "test_helper"

class TournamentGroupNamingTest < ActiveSupport::TestCase
  test "labels groups beyond Z without punctuation" do
    assert_equal "A", TournamentGroupNaming.label(0)
    assert_equal "Z", TournamentGroupNaming.label(25)
    assert_equal "AA", TournamentGroupNaming.label(26)
    assert_equal "IV", TournamentGroupNaming.label(255)
  end
end
