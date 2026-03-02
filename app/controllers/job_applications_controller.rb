class JobApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_application, only: [:show, :edit, :update, :destroy, :move]

  def index
    @job_applications = current_user.job_applications.recent.includes(:resume, :cover_letter)
    @grouped = @job_applications.group_by(&:status)
    @total = @job_applications.count
    @active_count = @job_applications.active.count
    @this_week = @job_applications.where('created_at >= ?', 1.week.ago).count
    @response_rate = calculate_response_rate
    @view = params[:view] || 'kanban'
  end

  def show
  end

  def new
    @job_application = current_user.job_applications.build(
      status: 'applied',
      applied_at: Date.current
    )
    @resumes = current_user.resumes.recent
    @cover_letters = current_user.cover_letters.recent
  end

  def create
    @job_application = current_user.job_applications.build(job_application_params)

    if @job_application.save
      ahoy.track "job_application_create", job_application_id: @job_application.id
      redirect_to @job_application, notice: 'Application tracked successfully!'
    else
      @resumes = current_user.resumes.recent
      @cover_letters = current_user.cover_letters.recent
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @resumes = current_user.resumes.recent
    @cover_letters = current_user.cover_letters.recent
  end

  def update
    if @job_application.update(job_application_params)
      redirect_to @job_application, notice: 'Application updated successfully.'
    else
      @resumes = current_user.resumes.recent
      @cover_letters = current_user.cover_letters.recent
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job_application.destroy
    redirect_to job_applications_path, notice: 'Application removed.'
  end

  def move
    if @job_application.update(status: params[:status])
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def set_job_application
    @job_application = current_user.job_applications.find(params[:id])
  end

  def job_application_params
    params.require(:job_application).permit(
      :company_name, :role, :url, :status, :applied_at, :follow_up_at,
      :notes, :salary_offered, :location, :remote, :contact_name,
      :contact_email, :resume_id, :cover_letter_id
    )
  end

  def calculate_response_rate
    total = current_user.job_applications.where.not(status: 'wishlist').count
    return 0 if total.zero?
    responded = current_user.job_applications.where(status: %w[phone_screen interview offer]).count
    ((responded.to_f / total) * 100).round(0)
  end
end
