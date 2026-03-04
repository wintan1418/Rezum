class InterviewPrepsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_premium!
  before_action :set_interview_prep, only: [ :show, :destroy ]

  def index
    @interview_preps = current_user.interview_preps.recent.includes(:resume)
  end

  def new
    @interview_prep = current_user.interview_preps.build
    @resumes = current_user.resumes.recent
    @job_applications = current_user.job_applications.recent
  end

  def create
    @interview_prep = current_user.interview_preps.build(interview_prep_params)

    unless current_user.has_active_subscription? || current_user.credits_remaining >= 3
      redirect_to new_interview_prep_path, alert: "You need at least 3 credits for Interview Prep. You have #{current_user.credits_remaining}."
      return
    end

    if @interview_prep.save
      ahoy.track "interview_prep_generate", interview_prep_id: @interview_prep.id
      GenerateInterviewPrepJob.perform_later(@interview_prep.id, current_user.id)
      redirect_to @interview_prep, notice: "Interview prep is being generated! This will take 30-60 seconds."
    else
      @resumes = current_user.resumes.recent
      @job_applications = current_user.job_applications.recent
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @interview_prep.destroy
    redirect_to interview_preps_path, notice: "Interview prep deleted."
  end

  private

  def set_interview_prep
    @interview_prep = current_user.interview_preps.find(params[:id])
  end

  def interview_prep_params
    params.require(:interview_prep).permit(
      :job_description, :company_name, :target_role,
      :resume_id, :job_application_id, :provider
    )
  end
end
