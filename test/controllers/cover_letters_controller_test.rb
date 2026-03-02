require "test_helper"

class CoverLettersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @resume = resumes(:optimized_resume)
    @letter = cover_letters(:generated_letter)
    sign_in @user
  end

  test "redirects to login when not authenticated" do
    sign_out @user
    get cover_letters_path
    assert_response :redirect
  end

  test "should get index" do
    get cover_letters_path
    assert_response :success
  end

  test "should get new" do
    get new_resume_cover_letter_path(@resume)
    assert_response :success
  end

  test "should get show" do
    get resume_cover_letter_path(@resume, @letter)
    assert_response :success
  end

  test "should get edit" do
    get edit_resume_cover_letter_path(@resume, @letter)
    assert_response :success
  end

  test "should update cover letter" do
    patch resume_cover_letter_path(@resume, @letter), params: {
      cover_letter: { company_name: "New Corp" }
    }
    assert_redirected_to resume_cover_letter_path(@resume, @letter)
    assert_equal "New Corp", @letter.reload.company_name
  end

  test "should destroy cover letter without FK conflict" do
    # Create a standalone cover letter not referenced by any job_application
    letter = @resume.cover_letters.create!(
      user: @user,
      company_name: "Deletable Corp",
      target_role: "Tester",
      tone: "professional",
      length: "short",
      status: "draft"
    )
    assert_difference("CoverLetter.count", -1) do
      delete resume_cover_letter_path(@resume, letter)
    end
  end
end
