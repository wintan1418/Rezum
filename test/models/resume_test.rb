require "test_helper"

class ResumeTest < ActiveSupport::TestCase
  setup do
    @draft = resumes(:draft_resume)
    @optimized = resumes(:optimized_resume)
    @processing = resumes(:processing_resume)
  end

  # Validations
  test "valid resume" do
    assert @draft.valid?
  end

  test "requires original_content" do
    @draft.original_content = nil
    assert_not @draft.valid?
  end

  test "original_content minimum length" do
    @draft.original_content = "short"
    assert_not @draft.valid?
  end

  test "requires target_role" do
    @draft.target_role = nil
    assert_not @draft.valid?
  end

  test "status must be valid" do
    assert_raises(ArgumentError) { @draft.status = "invalid" }
  end

  test "ats_score must be in range 0-100" do
    @optimized.ats_score = 101
    assert_not @optimized.valid?
  end

  # Enums
  test "status enum values" do
    assert Resume.statuses.key?("draft")
    assert Resume.statuses.key?("processing")
    assert Resume.statuses.key?("optimized")
    assert Resume.statuses.key?("failed")
  end

  # Methods
  test "optimized? returns true for optimized resume with content" do
    assert @optimized.optimized?
  end

  test "optimized? returns false for draft" do
    assert_not @draft.optimized?
  end

  test "processing? returns true for processing resume" do
    assert @processing.processing?
  end

  test "keywords_array splits keywords string" do
    assert_equal ["product management", "agile", "roadmap", "stakeholder"], @optimized.keywords_array
  end

  test "keywords_array returns empty array when nil" do
    assert_equal [], @draft.keywords_array
  end

  test "ats_score_color returns correct color" do
    assert_equal "green", @optimized.ats_score_color

    @optimized.ats_score = 30
    assert_equal "red", @optimized.ats_score_color

    @optimized.ats_score = 55
    assert_equal "yellow", @optimized.ats_score_color
  end

  test "ats_score_color returns gray when blank" do
    assert_equal "gray", @draft.ats_score_color
  end

  # Scopes
  test "optimized scope" do
    optimized = Resume.optimized
    assert_includes optimized, @optimized
    assert_not_includes optimized, @draft
  end

  test "recent scope orders by created_at desc" do
    recent = Resume.recent
    assert_equal recent.first.created_at, recent.map(&:created_at).max
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:taylor), @draft.user
  end

  test "has many cover_letters" do
    assert_respond_to @optimized, :cover_letters
  end

  # Callbacks
  test "strip_code_fences removes markdown fences" do
    resume = users(:taylor).resumes.build(
      original_content: "```plaintext\n#{'X' * 150}\n```",
      target_role: "Developer",
      status: "draft"
    )
    resume.save!
    assert_not_includes resume.original_content, "```"
  end
end
