class ResumeWizardController < ApplicationController
  CREDIT_COST = 10

  before_action :authenticate_user!

  def new
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

    # Premium users get it free and permanent; others get a locked 3-day preview
    if current_user.has_premium_subscription?
      # No expiry, no credit cost — full access
    else
      resume.update!(expires_at: 3.days.from_now)
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
    @unlocked = current_user.has_premium_subscription? || @resume.expires_at.nil?
  end

  # Pay 10 credits to unlock the resume (remove blur, enable download, make permanent)
  def unlock
    @resume = current_user.resumes.find(params[:id])

    # Already unlocked
    if @resume.expires_at.nil?
      redirect_to preview_resume_wizard_path(@resume), notice: "This resume is already unlocked." and return
    end

    # Premium users don't need credits
    if current_user.has_premium_subscription?
      @resume.update!(expires_at: nil)
      redirect_to preview_resume_wizard_path(@resume), notice: "Resume unlocked!" and return
    end

    # Check credits
    if current_user.credits_remaining < CREDIT_COST
      redirect_to preview_resume_wizard_path(@resume), alert: "You need #{CREDIT_COST} credits to unlock this resume. You have #{current_user.credits_remaining}." and return
    end

    # Deduct credits and unlock
    current_user.decrement!(:credits_remaining, CREDIT_COST)
    @resume.update!(expires_at: nil)

    redirect_to preview_resume_wizard_path(@resume), notice: "Resume unlocked! #{CREDIT_COST} credits used. You can now download and edit it."
  end
end
