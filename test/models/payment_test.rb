require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @success = payments(:successful_payment)
    @pending = payments(:pending_payment)
    @failed = payments(:failed_payment)
  end

  # Validations
  test "valid payment" do
    assert @success.valid?
  end

  test "requires paystack_reference" do
    @success.paystack_reference = nil
    assert_not @success.valid?
  end

  test "requires unique paystack_reference" do
    dup = @success.dup
    assert_not dup.valid?
  end

  test "requires amount_cents" do
    @success.amount_cents = nil
    assert_not @success.valid?
  end

  test "amount_cents must be positive" do
    @success.amount_cents = 0
    assert_not @success.valid?
  end

  test "requires currency" do
    @success.currency = nil
    assert_not @success.valid?
  end

  # Methods
  test "successful? returns true for success status" do
    assert @success.successful?
    assert_not @pending.successful?
    assert_not @failed.successful?
  end

  test "failed? returns true for failed status" do
    assert @failed.failed?
    assert_not @success.failed?
  end

  test "pending? returns true for pending status" do
    assert @pending.pending?
    assert_not @success.pending?
  end

  test "amount_display formats with currency symbol" do
    assert_equal "\u20A6500", @success.amount_display
  end

  test "currency_symbol for NGN" do
    assert_equal "\u20A6", @success.currency_symbol
  end

  test "currency_symbol for USD" do
    @success.currency = "USD"
    assert_equal "$", @success.currency_symbol
  end

  test "description_display shows description" do
    assert_equal "10 Credits Purchase", @success.description_display
  end

  test "description_display fallback for credits" do
    @success.description = nil
    @success.credits_purchased = 10
    assert_match(/Credits Purchase/, @success.description_display)
  end

  test "description_display fallback for no credits" do
    @success.description = nil
    @success.credits_purchased = nil
    assert_equal "Payment", @success.description_display
  end

  # Scopes
  test "successful scope" do
    successful = Payment.successful
    assert_includes successful, @success
    assert_not_includes successful, @pending
    assert_not_includes successful, @failed
  end

  test "recent scope orders by created_at desc" do
    recent = Payment.recent
    assert recent.first.created_at >= recent.last.created_at
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:taylor), @success.user
  end
end
