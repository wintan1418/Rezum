class OptimizeResumeJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(resume_id, user_id)
    resume = Resume.find(resume_id)
    user = User.find(user_id)

    return unless resume.processing?

    begin
      # Detect re-optimization: ATS feedback available from previous analysis
      has_ats_feedback = resume.ats_score.present? && resume.respond_to?(:ats_analysis) && resume.ats_analysis.present?

      # Always use original content as base — re-polishing polished text
      # produces near-identical output. Instead, start fresh with ATS feedback.
      service = ResumeOptimizerService.new(
        content: resume.original_content,
        job_description: resume.job_description,
        target_role: resume.target_role,
        industry: resume.industry,
        experience_level: resume.experience_level,
        user_id: user.id,
        user_country: user.country_code,
        provider: resume.provider,
        previous_ats_score: has_ats_feedback ? resume.ats_score : nil,
        previous_ats_analysis: has_ats_feedback ? resume.ats_analysis : nil
      )

      # Generate optimized resume
      optimized_content = service.optimize

      # Strip markdown code fences the AI sometimes wraps content in
      optimized_content = strip_code_fences(optimized_content)

      # Extract keywords
      keywords = service.extract_keywords

      # Update resume with results
      update_attrs = {
        optimized_content: optimized_content,
        keywords: keywords,
        status: "optimized",
        ats_score: nil
      }
      update_attrs[:ats_analysis] = nil if resume.respond_to?(:ats_analysis)
      resume.update!(update_attrs)

      # Auto-parse optimized content into structured sections for template rendering
      rebuild_sections_from_content(resume)

      # Deduct 2 credits for resume optimization
      # Skip if resume is locked (LinkedIn/wizard) — credits charged on unlock instead
      if resume.expires_at.nil? && user.free? && user.credits_remaining > 0
        credits_to_deduct = [ 2, user.credits_remaining ].min
        user.decrement!(:credits_remaining, credits_to_deduct)
      end

      # Auto-trigger ATS analysis if job description is present
      # so user sees their new score without clicking "Analyze" manually
      if resume.job_description.present?
        resume.update!(status: "processing")
        AnalyzeAtsScoreJob.perform_later(resume.id)
      end

      Rails.logger.info "Resume #{resume.id} optimized successfully for user #{user.id}"

    rescue StandardError => e
      resume.update!(status: "failed")
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

    # Strip trailing AI commentary/summary that starts with common patterns
    content = content.sub(/\n{2,}[-—=]{3,}.*\z/m, "")
    content = content.sub(/\n{2,}(?:This resume has been|Key changes|Note:|I've |The resume|Changes made|Summary of|Optimization notes).*\z/mi, "")
    content = content.sub(/\n{2,}\*{2,}(?:Key |Note|Changes).*\z/mi, "")

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
end
