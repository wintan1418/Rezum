require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  TEST_KEY = "sk_test_fake_key_for_testing"

  setup do
    @payment = payments(:pending_payment)
    @subscription = subscriptions(:active_subscription)
    @original_key = Rails.application.config.paystack.secret_key
    Rails.application.config.paystack.secret_key ||= TEST_KEY
  end

  teardown do
    Rails.application.config.paystack.secret_key = @original_key
  end

  test "rejects request without valid signature" do
    post "/webhooks/paystack",
      params: { event: "charge.success", data: {} }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "X-Paystack-Signature" => "invalid_signature"
      }
    assert_response :bad_request
  end

  test "rejects request with empty payload" do
    payload = ""
    signature = OpenSSL::HMAC.hexdigest(
      "SHA512",
      PaystackService.secret_key,
      payload
    )

    post "/webhooks/paystack",
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-Paystack-Signature" => signature
      }
    assert_response :bad_request
  end

  test "handles charge.success event" do
    payload = {
      event: "charge.success",
      data: {
        reference: @payment.paystack_reference,
        status: "success",
        amount: @payment.amount_cents,
        currency: "NGN"
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest(
      "SHA512",
      PaystackService.secret_key,
      payload
    )

    post "/webhooks/paystack",
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-Paystack-Signature" => signature
      }
    assert_response :ok
    assert_equal "success", @payment.reload.status
  end

  test "handles subscription.disable event" do
    payload = {
      event: "subscription.disable",
      data: {
        subscription_code: @subscription.paystack_subscription_code
      }
    }.to_json

    signature = OpenSSL::HMAC.hexdigest(
      "SHA512",
      PaystackService.secret_key,
      payload
    )

    post "/webhooks/paystack",
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-Paystack-Signature" => signature
      }
    assert_response :ok
    assert_equal "canceled", @subscription.reload.status
  end

  test "handles unknown event gracefully" do
    payload = {
      event: "unknown.event",
      data: {}
    }.to_json

    signature = OpenSSL::HMAC.hexdigest(
      "SHA512",
      PaystackService.secret_key,
      payload
    )

    post "/webhooks/paystack",
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-Paystack-Signature" => signature
      }
    assert_response :ok
  end
end
