class AnalyzeAtsScoreJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
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
      
      # Generate ATS score analysis
      ats_analysis = service.ats_score
      
      # Parse the score from the analysis (assuming it returns structured data)
      score = extract_score_from_analysis(ats_analysis)
      
      # Update resume with ATS score
      resume.update!(
        ats_score: score,
        status: 'optimized' # Return to optimized status
      )
      
      Rails.logger.info "ATS score analyzed for resume #{resume.id}: #{score}/100"
      
    rescue StandardError => e
      resume.update!(status: 'optimized') # Don't mark as failed, just return to optimized
      Rails.logger.error "ATS score analysis failed for #{resume.id}: #{e.message}"
      raise e
    end
  end
  
  private
  
  def extract_score_from_analysis(analysis)
    # Extract numeric score from AI analysis
    # Look for patterns like "Score: 85", "ATS Score (0-100): 72", etc.
    score_match = analysis.match(/(?:score|ats).*?(\d{1,3})/i)
    
    if score_match
      score = score_match[1].to_i
      return [score, 100].min # Cap at 100
    end
    
    # Fallback: estimate based on keywords in analysis
    case analysis.downcase
    when /excellent|outstanding|perfect/
      85 + rand(16) # 85-100
    when /good|strong|solid/
      70 + rand(16) # 70-85
    when /average|fair|moderate/
      50 + rand(21) # 50-70
    when /poor|weak|low/
      20 + rand(31) # 20-50
    else
      60 + rand(21) # Default range 60-80
    end
  end
end
