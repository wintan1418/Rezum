class OptimizeResumeJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
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

      # Strip markdown code fences the AI sometimes wraps content in
      optimized_content = strip_code_fences(optimized_content)

      # Extract keywords
      keywords = service.extract_keywords

      # Update resume with results
      resume.update!(
        optimized_content: optimized_content,
        keywords: keywords,
        status: "optimized"
      )

      # Auto-parse optimized content into structured sections for template rendering
      rebuild_sections_from_content(resume)

      # Deduct 2 credits for resume optimization
      if user.free? && user.credits_remaining > 0
        credits_to_deduct = [2, user.credits_remaining].min
        user.decrement!(:credits_remaining, credits_to_deduct)
      end

      # Broadcast update to any connected browsers
      broadcast_resume_update(resume, "optimized")

      Rails.logger.info "Resume #{resume.id} optimized successfully for user #{user.id}"

    rescue StandardError => e
      resume.update!(status: "failed")
      broadcast_resume_update(resume, "failed")
      Rails.logger.error "Resume optimization failed for #{resume.id}: #{e.message}"
      raise e
    end
  end

  private

  def strip_code_fences(content)
    return content if content.blank?

    # Remove opening ```plaintext, ```text, ```markdown, or just ```
    content = content.sub(/\A\s*```(?:plaintext|text|markdown|plain)?\s*\n?/, "")
    # Remove closing ```
    content = content.sub(/\n?\s*```\s*\z/, "")
    content.strip
  end

  def rebuild_sections_from_content(resume)
    parser = ResumeContentParserService.new(resume.optimized_content)
    parsed = parser.parse

    # Only destroy existing sections if parsing produced real results
    # (more than just a summary fallback)
    if parsed.blank? || (parsed.length == 1 && parsed.first[:section_type] == "summary" && parsed.first[:content]["text"]&.length.to_i < 50)
      Rails.logger.warn "Section parsing produced insufficient results for resume #{resume.id}, keeping existing sections"
      return
    end

    resume.resume_sections.destroy_all

    parsed.each do |section_data|
      resume.resume_sections.create!(
        section_type: section_data[:section_type],
        content: section_data[:content],
        position: section_data[:position],
        visible: true
      )
    end
  rescue => e
    Rails.logger.warn "Auto-parsing sections after optimization failed: #{e.message}"
  end

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
