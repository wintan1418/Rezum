require "test_helper"

class AnalyzeAtsScoreJobTest < ActiveJob::TestCase
  test "job can be enqueued" do
    resume = resumes(:optimized_resume)

    assert_enqueued_with(job: AnalyzeAtsScoreJob) do
      AnalyzeAtsScoreJob.perform_later(resume.id)
    end
  end
end
