require "test_helper"

class OptimizeResumeJobTest < ActiveJob::TestCase
  test "job can be enqueued" do
    resume = resumes(:draft_resume)
    user = users(:taylor)

    assert_enqueued_with(job: OptimizeResumeJob) do
      OptimizeResumeJob.perform_later(resume.id, user.id)
    end
  end

  test "job is queued in default queue" do
    assert_equal "default", OptimizeResumeJob.queue_name
  end
end
