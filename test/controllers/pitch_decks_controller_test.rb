require "test_helper"

class PitchDecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @own_deck = pitch_decks(:taylor_deck)
    @other_deck = pitch_decks(:pro_deck)
    sign_in @user
  end

  test "should show own pitch deck" do
    get pitch_deck_path(@own_deck)
    assert_response :success
  end

  test "should not show another user's pitch deck" do
    get pitch_deck_path(@other_deck)
    assert_response :not_found
  end

  test "should not delete another user's pitch deck" do
    assert_no_difference("PitchDeck.count") do
      delete pitch_deck_path(@other_deck)
    end
    assert_response :not_found
  end
end
