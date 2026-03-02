require "test_helper"

class PaystackServiceTest < ActiveSupport::TestCase
  test "secret_key returns configured key" do
    assert_not_nil PaystackService.secret_key
  end

  test "public_key returns configured key" do
    assert_not_nil PaystackService.public_key
  end

  test "test_mode? returns true for test keys" do
    if PaystackService.secret_key&.start_with?("sk_test_")
      assert PaystackService.test_mode?
    end
  end

  test "verify_webhook with valid signature" do
    payload = '{"event":"charge.success","data":{}}'
    signature = OpenSSL::HMAC.hexdigest("SHA512", PaystackService.secret_key, payload)
    assert PaystackService.verify_webhook(payload, signature)
  end

  test "verify_webhook with invalid signature" do
    payload = '{"event":"charge.success","data":{}}'
    assert_not PaystackService.verify_webhook(payload, "invalid_signature")
  end

  test "verify_webhook with tampered payload" do
    payload = '{"event":"charge.success","data":{}}'
    signature = OpenSSL::HMAC.hexdigest("SHA512", PaystackService.secret_key, payload)
    tampered = '{"event":"charge.success","data":{"amount":999999}}'
    assert_not PaystackService.verify_webhook(tampered, signature)
  end

  test "verify_webhook with nil signature" do
    payload = '{"event":"charge.success","data":{}}'
    assert_not PaystackService.verify_webhook(payload, nil)
  end
end
