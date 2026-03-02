class GenerateInterviewPrepJob < ApplicationJob
  queue_as :default

  def perform(interview_prep_id, user_id)
    prep = InterviewPrep.find(interview_prep_id)
    user = User.find(user_id)

    prep.update!(status: "generating")

    resume_content = prep.resume&.original_content

    service = InterviewPrepService.new(
      job_description: prep.job_description,
      company_name: prep.company_name,
      target_role: prep.target_role,
      resume_content: resume_content,
      user_id: user_id,
      user_country: user.country_code,
      provider: prep.provider || "openai"
    )

    questions = service.generate_questions
    company_questions = service.generate_company_questions

    prep.update!(
      questions: questions,
      company_questions: company_questions,
      status: "generated"
    )

    # Deduct 3 credits for interview prep (most AI-intensive)
    if user.free? && user.credits_remaining > 0
      credits_to_deduct = [ 3, user.credits_remaining ].min
      user.decrement!(:credits_remaining, credits_to_deduct)
    end
  rescue => e
    Rails.logger.error "Interview prep generation failed: #{e.message}"
    prep&.update(status: "failed")
  end
end
