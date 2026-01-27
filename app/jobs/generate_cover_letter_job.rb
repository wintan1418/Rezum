class GenerateCoverLetterJob < ApplicationJob
  queue_as :default
  

  discard_on ActiveRecord::RecordNotFound
  
  def perform(cover_letter_id, user_id)
    cover_letter = CoverLetter.find(cover_letter_id)
    user = User.find(user_id)
    resume = cover_letter.resume
    
    return unless cover_letter.generating?
    
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
      
      # Generate cover letter content
      generated_content = service.generate
      
      # Update cover letter with results
      cover_letter.update!(
        content: generated_content,
        status: 'generated'
      )
      
      # Deduct credits for pay-per-use users
      if user.free? && user.credits_remaining > 0
        user.decrement!(:credits_remaining)
      end
      
      # Broadcast update to any connected browsers
      broadcast_cover_letter_update(cover_letter, 'generated')
      
      Rails.logger.info "Cover letter #{cover_letter.id} generated successfully for user #{user.id}"
      
    rescue StandardError => e
      cover_letter.update!(status: 'failed')
      broadcast_cover_letter_update(cover_letter, 'failed')
      Rails.logger.error "Cover letter generation failed for #{cover_letter.id}: #{e.message}"
      raise e
    end
  end

  private

  def broadcast_cover_letter_update(cover_letter, status)
    # Broadcast to the specific cover letter channel
    Turbo::StreamsChannel.broadcast_replace_to(
      "cover_letter_#{cover_letter.id}",
      target: "cover_letter_content",
      partial: "cover_letters/content",
      locals: { cover_letter: cover_letter, resume: cover_letter.resume }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast cover letter update: #{e.message}"
    # Don't raise, as this is not critical to the job success
  end
end
