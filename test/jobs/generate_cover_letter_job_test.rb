require "test_helper"

class GenerateCoverLetterJobTest < ActiveJob::TestCase
  test "job can be enqueued" do
    letter = cover_letters(:draft_letter)

    assert_enqueued_with(job: GenerateCoverLetterJob) do
      GenerateCoverLetterJob.perform_later(letter.id)
    end
  end
end
