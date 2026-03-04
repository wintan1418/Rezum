require "test_helper"

class ResumesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @resume = resumes(:draft_resume)
    @optimized = resumes(:optimized_resume)
    sign_in @user
  end

  test "redirects to login when not authenticated" do
    sign_out @user
    get resumes_path
    assert_response :redirect
  end

  test "should get index" do
    get resumes_path
    assert_response :success
  end

  test "should get new" do
    get new_resume_path
    assert_response :success
  end

  test "should get show" do
    get resume_path(@resume)
    assert_response :success
  end

  test "should get edit" do
    get edit_resume_path(@resume)
    assert_response :success
  end

  test "should create resume with valid params" do
    assert_difference("Resume.count") do
      post resumes_path, params: {
        resume: {
          original_content: "A" * 150,
          target_role: "Software Engineer",
          industry: "Technology",
          experience_level: "mid"
        }
      }
    end
    assert_redirected_to resume_path(Resume.last)
  end

  test "should not create resume with invalid params" do
    assert_no_difference("Resume.count") do
      post resumes_path, params: {
        resume: {
          original_content: "too short",
          target_role: ""
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should update resume" do
    patch resume_path(@resume), params: {
      resume: { target_role: "Senior Engineer" }
    }
    assert_redirected_to resume_path(@resume)
    assert_equal "Senior Engineer", @resume.reload.target_role
  end

  test "should destroy resume" do
    assert_difference("Resume.count", -1) do
      delete resume_path(@resume)
    end
    assert_redirected_to resumes_path
  end

  test "should not access other user's resume" do
    other_resume = resumes(:processing_resume)
    get resume_path(other_resume)
    assert_response :not_found
  end

  test "optimize redirects when no credits" do
    broke = users(:broke_user)
    sign_in broke
    broke_resume = broke.resumes.create!(
      original_content: "X" * 150,
      target_role: "Developer",
      status: "draft"
    )
    post optimize_resume_path(broke_resume)
    assert_redirected_to resume_path(broke_resume)
    assert_match(/credits/i, flash[:alert])
  end

  test "optimize redirects when no content" do
    # Create valid resume then clear content to simulate edge case
    empty_resume = @user.resumes.create!(
      original_content: "X" * 150,
      target_role: "Developer",
      status: "draft"
    )
    empty_resume.update_column(:original_content, "")
    post optimize_resume_path(empty_resume)
    assert_redirected_to edit_resume_path(empty_resume)
    assert_match(/no content/i, flash[:alert])
  end
end
