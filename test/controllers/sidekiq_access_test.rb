require "test_helper"

class SidekiqAccessTest < ActionDispatch::IntegrationTest
  test "regular users cannot access sidekiq dashboard" do
    sign_in users(:taylor)

    get "/sidekiq"
    assert_response :not_found
  end

end
