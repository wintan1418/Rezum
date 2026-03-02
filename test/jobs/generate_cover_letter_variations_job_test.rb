require "test_helper"

class GenerateCoverLetterVariationsJobTest < ActiveJob::TestCase
  test "job can be enqueued" do
    letter = cover_letters(:generated_letter)

    assert_enqueued_with(job: GenerateCoverLetterVariationsJob) do
      GenerateCoverLetterVariationsJob.perform_later(letter.id)
    end
  end
end
