require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get landing page" do
    get root_path
    assert_response :success
  end

  test "landing page contains app name" do
    get root_path
    assert_response :success
  end
end
