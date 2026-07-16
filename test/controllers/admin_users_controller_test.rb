require "test_helper"

class AdminUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:taylor)
    @admin.update!(admin: true)
    @target = users(:broke_user)
    sign_in @admin
  end

  test "grant_subscription creates an active complimentary premium subscription" do
    assert_difference "@target.subscriptions.count", 1 do
      post grant_subscription_admin_user_path(@target), params: { plan: "premium", duration: "90" }
    end

    subscription = @target.subscriptions.order(:created_at).last
    assert subscription.paystack_subscription_code.start_with?("comp_")
    assert_equal "price_monthly_premium", subscription.plan_id
    assert_equal "active", subscription.status
    assert_in_delta 90.days.from_now.to_i, subscription.current_period_end.to_i, 60
    assert @target.reload.has_premium_subscription?
  end

  test "granting again replaces the previous complimentary subscription" do
    post grant_subscription_admin_user_path(@target), params: { plan: "pro", duration: "30" }
    first = @target.subscriptions.order(:created_at).last

    post grant_subscription_admin_user_path(@target), params: { plan: "premium", duration: "365" }

    assert_equal "canceled", first.reload.status
    assert @target.reload.has_premium_subscription?
  end

  test "grant_subscription rejects invalid plan or duration" do
    assert_no_difference "@target.subscriptions.count" do
      post grant_subscription_admin_user_path(@target), params: { plan: "enterprise", duration: "30" }
      post grant_subscription_admin_user_path(@target), params: { plan: "pro", duration: "7" }
    end
  end

  test "revoke_subscription cancels complimentary access" do
    post grant_subscription_admin_user_path(@target), params: { plan: "pro", duration: "30" }
    assert @target.reload.has_active_subscription?

    delete revoke_subscription_admin_user_path(@target)

    assert_not @target.reload.has_active_subscription?
  end

  test "admins cannot toggle their own admin flag" do
    patch toggle_admin_admin_user_path(@admin)

    assert @admin.reload.admin?
    assert_match(/cannot change your own/i, flash[:alert])
  end

  test "non-admins are blocked" do
    sign_in @target
    post grant_subscription_admin_user_path(@admin), params: { plan: "pro", duration: "30" }
    assert_redirected_to root_path
  end
end
