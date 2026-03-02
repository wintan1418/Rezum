class ResumeWizardController < ApplicationController
  CREDIT_COST = 5

  before_action :authenticate_user!

  def new
    # Public — anyone can try the wizard
  end

  def create
    # Check if user can afford it (Premium = free, others need 5 credits)
    unless current_user.has_premium_subscription?
      unless current_user.credits_remaining >= CREDIT_COST
        render json: { error: "You need #{CREDIT_COST} credits to generate a resume. You have #{current_user.credits_remaining}." }, status: :unprocessable_entity
        return
      end
    end

    wizard_params = JSON.parse(request.body.read)["wizard"]

    service = ResumeGeneratorService.new(
      user_id: current_user.id,
      full_name: wizard_params["full_name"],
      email: wizard_params["email"],
      phone: wizard_params["phone"],
      location: wizard_params["location"],
      target_role: wizard_params["target_role"],
      industry: wizard_params["industry"],
      experience_level: wizard_params["experience_level"],
      experiences: wizard_params["experiences"] || [],
      educations: wizard_params["educations"] || [],
      skills: wizard_params["skills"],
      certifications: wizard_params["certifications"],
      additional_info: wizard_params["additional_info"]
    )

    resume = service.create_resume!(current_user)

    # Deduct credits for non-premium users
    unless current_user.has_premium_subscription?
      current_user.decrement!(:credits_remaining, CREDIT_COST)
    end

    render json: { redirect_url: preview_resume_wizard_path(resume) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "ResumeWizard create error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: "Failed to generate resume. Please try again." }, status: :unprocessable_entity
  end

  def preview
    @resume = current_user.resumes.find(params[:id])
    service = ResumeTemplateService.new(resume: @resume)
    @preview_html = service.render_html_preview
    @premium = current_user.has_premium_subscription?
  end
end
