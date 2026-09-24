require "test_helper"

class FriendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("friends-html-#{SecureRandom.hex(4)}@example.com")
    @other = create_user("friends-other-#{SecureRandom.hex(4)}@example.com")
    @user.update!(nickname: "Alice")
    @other.update!(nickname: "Bob", discoverable_by_nickname: true, friend_request_policy: "anyone")
    FeatureAccess.stubs(:enabled?).returns(false)
    FeatureAccess.stubs(:enabled?).with(:friends).returns(true)
    login_as(@user)
  end

  test "search never uses email and exact nickname can send and accept request" do
    get search_friends_path(q: @other.email_address)
    assert_response :success
    assert_select "form[action='#{friend_requests_path}']", count: 0

    get search_friends_path(q: "Bob")
    assert_select "form[action='#{friend_requests_path}']", count: 1
    post friend_requests_path, params: { recipient_id: @other.public_id }
    assert_redirected_to friends_path

    delete session_path
    login_as(@other)
    request_record = @other.received_friend_requests.pending.first!
    post accept_friend_request_path(request_record)
    assert Friendship.between(@user, @other)
  end

  test "dashboard collections use bounded look-ahead pagination" do
    26.times do |index|
      friend = create_user("friends-page-#{index}-#{SecureRandom.hex(4)}@example.com")
      Friendship.create_between!(@user, friend)
    end

    get friends_path
    assert_response :success
    assert_select "form[action='#{challenges_path}']", count: FriendsController::PER_PAGE
    assert_select "a[href*='friendships_page=2']", text: I18n.t("common.pagination.next")

    get friends_path(friendships_page: 2)
    assert_response :success
    assert_select "form[action='#{challenges_path}']", count: 1
  end

  test "updates privacy controls and disabled flag conceals page" do
    patch friends_path, params: { user: { discoverable_by_nickname: true, friend_request_policy: "nobody", challenge_policy: "nobody" } }
    assert_redirected_to friends_path
    assert @user.reload.discoverable_by_nickname?
    assert_equal "nobody", @user.friend_request_policy

    FeatureAccess.unstub(:enabled?)
    FeatureAccess.stubs(:enabled?).returns(false)
    FeatureAccess.stubs(:enabled?).with(:friends).returns(false)
    get friends_path
    assert_response :not_found
  end
end
