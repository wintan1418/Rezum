class GenerateCoverLetterVariationsJob < ApplicationJob
  queue_as :default


  discard_on ActiveRecord::RecordNotFound

  def perform(cover_letter_id, user_id, count = 3)
    cover_letter = CoverLetter.find(cover_letter_id)
    user = User.find(user_id)
    resume = cover_letter.resume

    return unless cover_letter.generated?

    begin
      service = CoverLetterGeneratorService.new(
        resume_content: resume.optimized_content.presence || resume.original_content,
        job_description: cover_letter.job_description,
        company_name: cover_letter.company_name,
        hiring_manager_name: cover_letter.hiring_manager_name,
        target_role: cover_letter.target_role,
        tone: cover_letter.tone,
        length: cover_letter.length,
        user_id: user.id,
        user_country: user.country_code,
        provider: cover_letter.provider
      )

      # Generate variations
      variations = service.generate_variations(count: count)

      variations.each_with_index do |variation, index|
        # Create new cover letter for each variation
        variation_letter = resume.cover_letters.create!(
          user: user,
          company_name: cover_letter.company_name,
          hiring_manager_name: cover_letter.hiring_manager_name,
          target_role: cover_letter.target_role,
          tone: cover_letter.tone,
          length: cover_letter.length,
          content: variation[:content],
          language: variation[:language] || "en",
          job_description: cover_letter.job_description,
          status: "generated",
          provider: variation[:provider].to_s,
          variation_of: cover_letter
        )

        Rails.logger.info "Cover letter variation #{index + 1} created as #{variation_letter.id}"
      end

      if user.free?
        user.deduct_credits!(count * CreditPolicy::COVER_LETTER)
      end

      Rails.logger.info "Generated #{variations.size} cover letter variations for user #{user.id}"

    rescue StandardError => e
      Rails.logger.error "Cover letter variations generation failed for #{cover_letter.id}: #{e.message}"
      raise e
    end
  end
end
