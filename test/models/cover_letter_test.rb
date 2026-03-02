require "test_helper"

class CoverLetterTest < ActiveSupport::TestCase
  setup do
    @generated = cover_letters(:generated_letter)
    @draft = cover_letters(:draft_letter)
  end

  # Validations
  test "valid cover letter" do
    assert @generated.valid?
  end

  test "requires company_name" do
    @generated.company_name = nil
    assert_not @generated.valid?
  end

  test "requires target_role" do
    @generated.target_role = nil
    assert_not @generated.valid?
  end

  test "tone must be valid" do
    assert_raises(ArgumentError) { @generated.tone = "angry" }
  end

  test "length must be valid" do
    assert_raises(ArgumentError) { @generated.length = "enormous" }
  end

  test "content required when status is generated" do
    @generated.content = nil
    assert_not @generated.valid?
  end

  test "content not required when status is draft" do
    @draft.content = nil
    assert @draft.valid?
  end

  # Methods
  test "generated? returns true for generated letter with content" do
    assert @generated.generated?
  end

  test "generated? returns false for draft" do
    assert_not @draft.generated?
  end

  test "word_count returns number of words" do
    assert @generated.word_count > 0
  end

  test "word_count returns 0 when no content" do
    @draft.content = nil
    assert_equal 0, @draft.word_count
  end

  test "estimated_read_time" do
    assert_match(/min/, @generated.estimated_read_time)
  end

  test "display_tone humanizes tone" do
    assert_equal "Professional", @generated.display_tone
  end

  test "display_length for medium" do
    assert_match(/300-400/, @generated.display_length)
  end

  # Scopes
  test "recent scope" do
    recent = CoverLetter.recent
    assert recent.first.created_at >= recent.last.created_at
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:taylor), @generated.user
  end

  test "belongs to resume" do
    assert_equal resumes(:optimized_resume), @generated.resume
  end
end
