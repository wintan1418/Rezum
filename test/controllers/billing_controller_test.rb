require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get billing_index_url
    assert_response :success
  end

  test "should get show" do
    get billing_show_url
    assert_response :success
  end
end
