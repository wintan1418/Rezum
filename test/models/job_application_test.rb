require "test_helper"

class JobApplicationTest < ActiveSupport::TestCase
  setup do
    @applied = job_applications(:applied_job)
    @interview = job_applications(:interview_job)
    @followup = job_applications(:needs_followup_job)
  end

  # Validations
  test "valid job application" do
    assert @applied.valid?
  end

  test "requires company_name" do
    @applied.company_name = nil
    assert_not @applied.valid?
  end

  test "requires role" do
    @applied.role = nil
    assert_not @applied.valid?
  end

  # Enums
  test "status enum values" do
    assert JobApplication.statuses.key?("wishlist")
    assert JobApplication.statuses.key?("applied")
    assert JobApplication.statuses.key?("interview")
    assert JobApplication.statuses.key?("offer")
    assert JobApplication.statuses.key?("rejected")
  end

  # Methods
  test "status_color returns correct color" do
    assert_equal "blue", @applied.status_color
    assert_equal "purple", @interview.status_color
  end

  test "status_emoji returns correct emoji" do
    assert @applied.status_emoji.present?
    assert @interview.status_emoji.present?
  end

  test "days_since_applied calculates correctly" do
    days = @applied.days_since_applied
    assert_kind_of Integer, days
    assert days >= 0
  end

  test "days_since_applied returns nil without applied_at" do
    @applied.applied_at = nil
    assert_nil @applied.days_since_applied
  end

  test "needs_follow_up? returns true when overdue" do
    assert @followup.needs_follow_up?
  end

  test "needs_follow_up? returns true for interview status with past follow_up_at" do
    @interview.follow_up_at = 1.day.ago
    assert @interview.needs_follow_up?
  end

  test "needs_follow_up? returns false for rejected status" do
    @followup.status = "rejected"
    assert_not @followup.needs_follow_up?
  end

  # Scopes
  test "active scope" do
    active = JobApplication.active
    assert_includes active, @applied
    assert_includes active, @interview
  end

  test "needs_follow_up scope" do
    followups = JobApplication.needs_follow_up
    assert_includes followups, @followup
  end

  test "recent scope" do
    recent = JobApplication.recent
    assert recent.first.updated_at >= recent.last.updated_at
  end

  # Associations
  test "belongs to user" do
    assert_equal users(:taylor), @applied.user
  end

  test "optional resume association" do
    @interview.resume = nil
    assert @interview.valid?
  end
end
