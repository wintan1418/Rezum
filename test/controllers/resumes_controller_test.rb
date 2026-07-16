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

  test "tailor renders for optimized resume with job description" do
    get tailor_resume_path(@optimized)
    assert_response :success
  end

  test "tailor redirects for non-optimized resume" do
    get tailor_resume_path(@resume)
    assert_redirected_to resume_path(@resume)
  end

  test "apply_bullet inserts under role anchor and recomputes match" do
    @optimized.update!(
      optimized_content: "Jane Doe\n\nEXPERIENCE\nProduct Manager | Acme | 2020-2024\n- Shipped roadmap features\n\nSKILLS\nAgile, Roadmap",
      keyword_match_data: {
        "keywords" => [
          { "term" => "stakeholder management", "category" => "required_hard_skills" },
          { "term" => "Agile", "category" => "required_hard_skills" }
        ],
        "matched" => [], "missing" => [], "match_rate" => 0
      }
    )

    post apply_bullet_resume_path(@optimized), params: {
      bullet: "Led stakeholder management across 4 teams",
      role: "Product Manager | Acme | 2020-2024"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    @optimized.reload

    assert_includes @optimized.optimized_content, "- Led stakeholder management across 4 teams"
    role_line = @optimized.optimized_content.index("Product Manager | Acme")
    bullet_line = @optimized.optimized_content.index("Led stakeholder management")
    assert role_line < bullet_line, "bullet should be inserted after its role header"
    assert_equal 100, body["match_rate"], "both keywords now present -> 100% match"
    assert_equal 2, body["matched"].size
  end

  test "apply_bullet appends when anchor missing and rejects blank bullet" do
    @optimized.update!(optimized_content: "Jane Doe\nEXPERIENCE\n- Did things")

    post apply_bullet_resume_path(@optimized), params: { bullet: "Improved metrics", role: "Nonexistent Role" }, as: :json
    assert_response :success
    assert @optimized.reload.optimized_content.end_with?("- Improved metrics")

    post apply_bullet_resume_path(@optimized), params: { bullet: "", role: "" }, as: :json
    assert_response :unprocessable_entity
  end

  test "suggest_bullets rejects blank keyword" do
    post suggest_bullets_resume_path(@optimized), params: { keyword: "" }, as: :json
    assert_response :unprocessable_entity
  end
end
