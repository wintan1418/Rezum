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

  test "should create cover letter without job description" do
    resume = resumes(:draft_resume)

    assert_difference("CoverLetter.count") do
      assert_enqueued_with(job: GenerateCoverLetterJob) do
        post resume_cover_letters_path(resume), params: {
          cover_letter: {
            company_name: "No JD Corp",
            target_role: "Software Engineer",
            tone: "professional",
            length: "short",
            provider: "openai"
          }
        }
      end
    end

    assert_redirected_to resume_cover_letter_path(resume, CoverLetter.last)
    assert_nil CoverLetter.last.job_description
  end

  test "downgrades anthropic cover letter provider for non premium users" do
    resume = resumes(:draft_resume)

    post resume_cover_letters_path(resume), params: {
      cover_letter: {
        company_name: "Provider Corp",
        target_role: "Software Engineer",
        tone: "professional",
        length: "short",
        provider: "anthropic"
      }
    }

    assert_equal "openai", CoverLetter.last.provider
  end

  test "should regenerate failed cover letter" do
    failed_letter = @resume.cover_letters.create!(
      user: @user,
      company_name: "Retry Corp",
      target_role: "Product Manager",
      tone: "professional",
      length: "short",
      status: "failed",
      provider: "openai"
    )

    assert_enqueued_with(job: GenerateCoverLetterJob) do
      post regenerate_resume_cover_letter_path(@resume, failed_letter)
    end

    assert_redirected_to resume_cover_letter_path(@resume, failed_letter)
    assert failed_letter.reload.generating?
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
