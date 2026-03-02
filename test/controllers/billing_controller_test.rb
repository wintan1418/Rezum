require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @payment = payments(:successful_payment)
    sign_in @user
  end

  test "redirects to login when not authenticated" do
    sign_out @user
    get billing_index_path
    assert_response :redirect
  end

  test "should get index" do
    get billing_index_path
    assert_response :success
  end

  test "should get show for payment" do
    get billing_path(@payment)
    assert_response :success
  end

  test "should get history" do
    get history_billing_index_path
    assert_response :success
  end

  test "purchase_credits rejects invalid amount" do
    post purchase_credits_billing_index_path, params: { credits: 0 }
    assert_redirected_to billing_index_path
    assert_match(/invalid/i, flash[:alert])
  end

  test "verify_payment rejects blank reference" do
    get verify_payment_billing_index_path
    assert_redirected_to billing_index_path
    assert_match(/invalid/i, flash[:alert])
  end

  test "verify_payment rejects unknown reference" do
    get verify_payment_billing_index_path, params: { reference: "nonexistent_ref" }
    assert_redirected_to billing_index_path
    assert_match(/not found/i, flash[:alert])
  end
end
