class OptimizeResumeJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound
  
  def perform(resume_id, user_id)
    resume = Resume.find(resume_id)
    user = User.find(user_id)
    
    return unless resume.processing?
    
    begin
      service = ResumeOptimizerService.new(
        content: resume.original_content,
        job_description: resume.job_description,
        target_role: resume.target_role,
        industry: resume.industry,
        experience_level: resume.experience_level,
        user_id: user.id,
        user_country: user.country_code,
        provider: resume.provider
      )
      
      # Generate optimized resume
      optimized_content = service.optimize
      
      # Extract keywords
      keywords = service.extract_keywords
      
      # Update resume with results
      resume.update!(
        optimized_content: optimized_content,
        keywords: keywords,
        status: 'optimized'
      )
      
      # Deduct credits for pay-per-use users
      if user.free? && user.credits_remaining > 0
        user.decrement!(:credits_remaining)
      end
      
      # Broadcast update to any connected browsers
      broadcast_resume_update(resume, 'optimized')
      
      Rails.logger.info "Resume #{resume.id} optimized successfully for user #{user.id}"
      
    rescue StandardError => e
      resume.update!(status: 'failed')
      broadcast_resume_update(resume, 'failed')
      Rails.logger.error "Resume optimization failed for #{resume.id}: #{e.message}"
      raise e
    end
  end

  private

  def broadcast_resume_update(resume, status)
    # Broadcast to the specific resume channel
    Turbo::StreamsChannel.broadcast_replace_to(
      "resume_#{resume.id}",
      target: "resume_content",
      partial: "resumes/content",
      locals: { resume: resume }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast resume update: #{e.message}"
    # Don't raise, as this is not critical to the job success
  end
end
