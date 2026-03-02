class ResumeWizardController < ApplicationController
  before_action :authenticate_user!, only: [ :create, :preview ]

  def new
    # Public — anyone can try the wizard
  end

  def create
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
    @subscribed = current_user.has_active_subscription?
  end
end
