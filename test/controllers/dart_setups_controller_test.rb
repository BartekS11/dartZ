require "test_helper"

class DartSetupsControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get edit_dart_setup_path

    assert_redirected_to new_session_path
  end

  test "anonymous user cannot save setup" do
    assert_no_difference("DartSetup.count") do
      patch dart_setup_path, params: {
        dart_setup: {
          manufacturer: "target",
          weight_g: 24.2,
          shaft_type: "carbon",
          shaft_length_mm: 42,
          point_length_mm: 35
        }
      }
    end

    assert_redirected_to new_session_path
  end

  test "requires premium access" do
    user = create_user("free-dart-setup@example.com")
    login_as(user)

    get edit_dart_setup_path

    assert_redirected_to matches_path
    assert_equal "Premium access is required for that feature.", flash[:alert]
  end

  test "free user cannot save setup" do
    user = create_user("free-save-dart-setup@example.com")
    login_as(user)

    assert_no_difference("DartSetup.count") do
      patch dart_setup_path, params: {
        dart_setup: {
          manufacturer: "target",
          weight_g: 24.2,
          shaft_type: "carbon",
          shaft_length_mm: 42,
          point_length_mm: 35
        }
      }
    end

    assert_redirected_to matches_path
    assert_equal "Premium access is required for that feature.", flash[:alert]
  end

  test "premium user can edit setup" do
    user = create_user("premium-dart-setup@example.com")
    user.update!(account_tier: "premium")
    login_as(user)

    get edit_dart_setup_path

    assert_response :success
    assert_select "h1", "Dart setup"
  end

  test "pro user can edit setup" do
    user = create_user("pro-dart-setup@example.com")
    user.update!(account_tier: "pro")
    login_as(user)

    get edit_dart_setup_path

    assert_response :success
    assert_select "h1", "Dart setup"
  end

  test "expired premium user cannot edit setup" do
    user = create_user("expired-dart-setup@example.com")
    user.update!(account_tier: "premium", premium_access_expires_at: 1.day.ago)
    login_as(user)

    get edit_dart_setup_path

    assert_redirected_to matches_path
    assert_equal "Premium access is required for that feature.", flash[:alert]
  end

  test "premium user can save setup" do
    user = create_user("save-dart-setup@example.com")
    user.update!(account_tier: "premium")
    login_as(user)

    assert_difference("DartSetup.count", 1) do
      patch dart_setup_path, params: {
        dart_setup: {
          manufacturer: "target",
          weight_g: 24.2,
          shaft_type: "carbon",
          shaft_length_mm: 42,
          point_length_mm: 35
        }
      }
    end

    assert_redirected_to edit_dart_setup_path
    setup = user.reload.dart_setup
    assert_equal "target", setup.manufacturer
    assert_equal BigDecimal("24.2"), setup.weight_g
    assert_equal "carbon", setup.shaft_type
    assert_equal 42, setup.shaft_length_mm
    assert_equal 35, setup.point_length_mm
  end
end
