class GenerateLinkedinOptimizationJob < ApplicationJob
  queue_as :default

  def perform(linkedin_optimization_id, user_id)
    optimization = LinkedinOptimization.find(linkedin_optimization_id)
    user = User.find(user_id)

    optimization.update!(status: "processing")

    resume_content = optimization.resume&.original_content

    service = LinkedinOptimizerService.new(
      current_headline: optimization.current_headline,
      current_about: optimization.current_about,
      current_experience: optimization.current_experience,
      target_role: optimization.target_role,
      resume_content: resume_content,
      user_id: user_id,
      user_country: user.country_code,
      provider: optimization.provider || "openai"
    )

    result = service.optimize

    optimization.update!(
      optimized_headline: Array(result["headline_options"]).join("\n---\n"),
      optimized_about: result["about"],
      optimized_experience: result["experience"],
      suggestions: result["suggestions"] || [],
      status: "optimized"
    )

    # Deduct 2 credits for LinkedIn optimization
    if user.free? && user.credits_remaining > 0
      credits_to_deduct = [2, user.credits_remaining].min
      user.decrement!(:credits_remaining, credits_to_deduct)
    end
  rescue => e
    Rails.logger.error "LinkedIn optimization failed: #{e.message}"
    optimization&.update(status: "failed")
  end
end
