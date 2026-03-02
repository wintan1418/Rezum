require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @active = subscriptions(:active_subscription)
    @canceled = subscriptions(:canceled_subscription)
  end

  # Validations
  test "valid subscription" do
    assert @active.valid?
  end

  test "requires paystack_subscription_code" do
    @active.paystack_subscription_code = nil
    assert_not @active.valid?
  end

  test "requires unique paystack_subscription_code" do
    dup = @active.dup
    assert_not dup.valid?
  end

  test "requires plan_id" do
    @active.plan_id = nil
    assert_not @active.valid?
  end

  # Methods
  test "active? returns true for active sub with future end date" do
    assert @active.active?
  end

  test "active? returns false for canceled sub with past end date" do
    assert_not @canceled.active?
  end

  test "expired? returns true for past end date" do
    assert @canceled.expired?
  end

  test "expired? returns false for future end date" do
    assert_not @active.expired?
  end

  test "days_until_renewal for active sub" do
    assert @active.days_until_renewal > 0
  end

  test "days_until_renewal returns 0 for expired sub" do
    assert_equal 0, @canceled.days_until_renewal
  end

  test "plan_name returns human-readable name" do
    assert_equal "Monthly Pro", @active.plan_name
    assert_equal "Annual Pro", @canceled.plan_name
  end

  test "plan_price returns correct price" do
    assert_equal 29, @active.plan_price
    assert_equal 290, @canceled.plan_price
  end

  test "billing_cycle returns correct cycle" do
    assert_equal "monthly", @active.billing_cycle
    assert_equal "annual", @canceled.billing_cycle
  end

  test "premium? returns false for pro plans" do
    assert_not @active.premium?
  end

  # Scopes
  test "active_subscriptions scope" do
    active_subs = Subscription.active_subscriptions
    assert_includes active_subs, @active
    assert_not_includes active_subs, @canceled
  end

  test "canceled_subscriptions scope" do
    canceled_subs = Subscription.canceled_subscriptions
    assert_includes canceled_subs, @canceled
    assert_not_includes canceled_subs, @active
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:pro_user), @active.user
  end
end
