require 'test_helper'

  class MatchesControllerTest < ActionController::TestCase
    fixtures :matches

    test "should get index" do
      get :index
      assert_response :success
      assert_equal "text/html", response.content_type
      assert_select "h1", text: "All Matches"
    end

    test "should create match" do
      assert_difference 'Match.count' do
        post :create, params: {
          match: {
            team1: 'Team A',
            team2: 'Team B',
            score1: 2,
            score2: 1
          }
        }
      end

      assert_redirected_to match_path(assigns(:match))
      assert_match(/Team A vs Team B/, response.body)
    end

    test "should not create match with invalid parameters" do
      post :create, params: {
        match: {
          team1: '',
          team2: '',
          score1: 2,
          score2: 1
        }
      }

      assert_response :unprocessable_entity
      assert_select "div.errorExplanation", text: "Team1 can't be blank"
    end

    test "should show match" do
      match = matches(:one)
      get :show, params: { id: match.to_param }
      assert_response :success
      assert_equal "text/html", response.content_type
      assert_select "h1", text: "Match Details"
    end

    test "should not show non-existent match" do
      get :show, params: { id: 999 }
      assert_response :not_found
    end

    test "should update match" do
      match = matches(:one)
      put :update, params: {
        id: match.to_param,
        match: {
          score1: 3,
          score2: 2
        }
      }

      assert_redirected_to match_path(assigns(:match))
      assert_match(/Score: 3-2/, response.body)
    end

    test "should not update match with invalid parameters" do
      match = matches(:one)
      put :update, params: {
        id: match.to_param,
        match: {
          team1: '',
          team2: '',
          score1: 3,
          score2: 2
        }
      }

      assert_response :unprocessable_entity
      assert_select "div.errorExplanation", text: "Team1 can't be blank"
    end

    test "should destroy match" do
      match = matches(:one)
      assert_difference 'Match.count', -1 do
        delete :destroy, params: { id: match.to_param }
      end

      assert_redirected_to matches_path
    end

    test "should not destroy non-existent match" do
      delete :destroy, params: { id: 999 }
      assert_response :not_found
    end
  end
