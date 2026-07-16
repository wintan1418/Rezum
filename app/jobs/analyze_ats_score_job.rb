class AnalyzeAtsScoreJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(resume_id)
    resume = Resume.find(resume_id)

    return unless resume.processing? && resume.optimized_content.present?

    begin
      service = ResumeOptimizerService.new(
        content: resume.optimized_content,
        job_description: resume.job_description,
        target_role: resume.target_role,
        industry: resume.industry,
        experience_level: resume.experience_level,
        user_id: resume.user_id,
        user_country: resume.user.country_code,
        provider: resume.provider
      )

      # Deterministic keyword gap data anchors the score so it is
      # reproducible instead of LLM guesswork
      keyword_match = compute_keyword_match(service, resume)

      # Generate ATS score analysis
      ats_analysis = service.ats_score(keyword_match: keyword_match)

      score = extract_score_from_analysis(ats_analysis)
      raise StandardError, "ATS analysis contained no parseable score" if score.nil?

      # Update resume with ATS score and full analysis
      resume.update!(
        ats_score: score,
        ats_analysis: ats_analysis,
        status: "optimized" # Return to optimized status
      )

      Rails.logger.info "ATS score analyzed for resume #{resume.id}: #{score}/100"

    rescue StandardError => e
      resume.update!(status: "optimized") # Don't mark as failed, just return to optimized
      Rails.logger.error "ATS score analysis failed for #{resume.id}: #{e.message}"
      raise e
    end
  end

  private

  # Extract keywords from the JD once, then match them deterministically
  # against the resume text. Degrades to nil (unanchored scoring) on failure.
  def compute_keyword_match(service, resume)
    return nil if resume.job_description.blank?

    keywords = service.extract_keywords_structured
    return nil if keywords.empty?

    KeywordMatchService.new(
      resume_text: resume.optimized_content,
      keywords: keywords
    ).match
  rescue StandardError => e
    Rails.logger.warn "Keyword match computation failed for resume #{resume.id}: #{e.message}"
    nil
  end

  def extract_score_from_analysis(analysis)
    # Preferred: the exact machine-readable line the prompt pins to English,
    # which stays stable even when the rest of the analysis is not in English
    exact_match = analysis.match(/OVERALL ATS SCORE:\s*(\d{1,3})/i)
    return [ exact_match[1].to_i, 100 ].min if exact_match

    # Extract numeric score from AI analysis
    # Look for patterns like "Score: 85", "ATS Score (0-100): 72", etc.
    score_match = analysis.match(/(?:score|ats).*?(\d{1,3})/i)
    return [ score_match[1].to_i, 100 ].min if score_match

    # No parseable score — the caller raises so the job retries rather than
    # fabricating a number the user would trust
    nil
  end
end
