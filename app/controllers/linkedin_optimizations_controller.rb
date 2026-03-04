class LinkedinOptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_paid_subscription!
  before_action :set_linkedin_optimization, only: [ :show, :destroy ]

  def index
    @linkedin_optimizations = current_user.linkedin_optimizations.recent.includes(:resume)
  end

  def new
    @linkedin_optimization = current_user.linkedin_optimizations.build
    @resumes = current_user.resumes.recent
  end

  def create
    @linkedin_optimization = current_user.linkedin_optimizations.build(linkedin_optimization_params)

    unless current_user.can_generate?
      redirect_to new_linkedin_optimization_path, alert: "Insufficient credits. Please upgrade your plan."
      return
    end

    if @linkedin_optimization.save
      ahoy.track "linkedin_optimize", linkedin_optimization_id: @linkedin_optimization.id
      GenerateLinkedinOptimizationJob.perform_later(@linkedin_optimization.id, current_user.id)
      redirect_to @linkedin_optimization, notice: "LinkedIn optimization started! This will take 30-60 seconds."
    else
      @resumes = current_user.resumes.recent
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @linkedin_optimization.destroy
    redirect_to linkedin_optimizations_path, notice: "LinkedIn optimization deleted."
  end

  private

  def set_linkedin_optimization
    @linkedin_optimization = current_user.linkedin_optimizations.find(params[:id])
  end

  def linkedin_optimization_params
    params.require(:linkedin_optimization).permit(
      :target_role, :current_headline, :current_about,
      :current_experience, :resume_id, :provider
    )
  end
end
