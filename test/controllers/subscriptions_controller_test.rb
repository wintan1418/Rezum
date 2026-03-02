require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @pro = users(:pro_user)
    @subscription = subscriptions(:active_subscription)
    sign_in @user
  end

  test "redirects to login when not authenticated" do
    sign_out @user
    get new_subscription_path
    assert_response :redirect
  end

  test "should get new" do
    get new_subscription_path
    assert_response :success
  end

  test "should get show for own subscription" do
    sign_in @pro
    get subscription_path(@subscription)
    assert_response :success
  end
end
