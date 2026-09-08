require "test_helper"

class VoiceAnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "configured account can download an allowlisted announcement" do
    user = create_user("TEST@example.com")
    login_as(user)

    get voice_announcement_path("180")

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert response.body.bytesize.positive?
  end

  test "unauthenticated request is hidden with not found" do
    get voice_announcement_path("180")

    assert_response :not_found
  end

  test "another account cannot download an announcement" do
    login_as(create_user("someone-else@example.com"))

    get voice_announcement_path("180")

    assert_response :not_found
  end

  test "unknown announcement key is hidden with not found" do
    login_as(create_user("test@example.com"))

    get voice_announcement_path("unknown")

    assert_response :not_found
  end
end
