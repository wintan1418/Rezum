require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "should get stripe" do
    get webhooks_stripe_url
    assert_response :success
  end
end
