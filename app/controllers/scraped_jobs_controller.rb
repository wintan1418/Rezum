class ScrapedJobsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_premium!
  before_action :set_scraped_job, only: [ :show, :update, :destroy, :tailor_resume ]

  def index
    @settings = current_user.job_scraper_setting || current_user.build_job_scraper_setting
    @scraped_jobs = current_user.scraped_jobs.not_hidden.recent

    # Filters
    @scraped_jobs = @scraped_jobs.by_status(params[:status]) if params[:status].present?
    @scraped_jobs = @scraped_jobs.where("match_score >= ?", params[:min_score].to_i) if params[:min_score].present?
    @scraped_jobs = @scraped_jobs.where(remote: true) if params[:remote] == "1"

    @stats = {
      total: current_user.scraped_jobs.count,
      new_count: current_user.scraped_jobs.by_status("new").count,
      saved_count: current_user.scraped_jobs.by_status("saved").count,
      applied_count: current_user.scraped_jobs.by_status("applied").count,
      high_match: current_user.scraped_jobs.high_match.count
    }

    @scraped_jobs = @scraped_jobs.page(params[:page]).per(20) if @scraped_jobs.respond_to?(:page)
  end

  def show
  end

  def update
    if @scraped_job.update(scraped_job_params)
      track_application! if @scraped_job.saved_change_to_status? && @scraped_job.status == "applied"
      redirect_back fallback_location: scraped_jobs_path, notice: "Job updated."
    else
      redirect_back fallback_location: scraped_jobs_path, alert: "Failed to update job."
    end
  end

  # Scraper → optimizer pipeline: spin up a resume draft pre-loaded with this
  # job's description so the user lands one click from optimizing against it.
  def tailor_resume
    source = current_user.resumes.optimized.recent.first || current_user.resumes.recent.first

    unless source
      redirect_to new_resume_path, alert: "Upload a resume first, then tailor it to this job."
      return
    end

    resume = current_user.resumes.create!(
      original_content: source.optimized_content.presence || source.original_content,
      target_role: @scraped_job.role.presence || source.target_role,
      industry: source.industry,
      experience_level: source.experience_level,
      job_description: @scraped_job.description,
      status: "draft",
      template: source.template,
      provider: "openai"
    )

    @scraped_job.update(status: "saved") if @scraped_job.status == "new"

    redirect_to resume, notice: "Resume draft created for #{@scraped_job.company_name} — review and optimize."
  end

  def destroy
    @scraped_job.update!(status: "hidden")
    redirect_back fallback_location: scraped_jobs_path, notice: "Job removed from list."
  end

  def scrape_now
    if current_user.job_scraper_setting.blank?
      redirect_to scraped_jobs_path, alert: "Please configure your job scraper settings first."
      return
    end

    current_user.update_column(:scraping_in_progress, true)
    ScrapeJobsJob.perform_later(current_user.id)
    redirect_to scraped_jobs_path, notice: "Job scraping started! Results will appear automatically."
  end

  def settings
    @settings = current_user.job_scraper_setting || current_user.build_job_scraper_setting
  end

  def update_settings
    @settings = current_user.job_scraper_setting || current_user.build_job_scraper_setting

    # Parse comma-separated values into arrays
    settings_data = settings_params.to_h
    settings_data[:target_roles] = parse_list(params[:job_scraper_setting][:target_roles_text])
    settings_data[:target_locations] = parse_list(params[:job_scraper_setting][:target_locations_text])
    settings_data[:keywords] = parse_list(params[:job_scraper_setting][:keywords_text])
    settings_data.delete(:target_roles_text)
    settings_data.delete(:target_locations_text)
    settings_data.delete(:keywords_text)

    if @settings.update(settings_data)
      redirect_to scraped_jobs_path, notice: "Scraper settings saved successfully."
    else
      render :settings
    end
  end

  private

  # Marking a scraped job "applied" drops it into the application tracker
  # automatically so the kanban stays in sync without manual entry.
  def track_application!
    @scraped_job.update(applied_at: Time.current) if @scraped_job.applied_at.blank?

    return if current_user.job_applications.exists?(
      company_name: @scraped_job.company_name, role: @scraped_job.role
    )

    current_user.job_applications.create(
      company_name: @scraped_job.company_name,
      role: @scraped_job.role,
      url: @scraped_job.url,
      location: @scraped_job.location,
      remote: @scraped_job.remote,
      status: "applied",
      applied_at: Date.current,
      notes: "Added automatically from the job scraper."
    )
  end

  def set_scraped_job
    @scraped_job = current_user.scraped_jobs.find(params[:id])
  end

  def scraped_job_params
    params.require(:scraped_job).permit(:status, :notes)
  end

  def settings_params
    params.require(:job_scraper_setting).permit(
      :scrape_frequency, :remote_only, :auto_apply, :enabled,
      :min_salary, :experience_level, :max_results_per_scrape,
      :target_roles_text, :target_locations_text, :keywords_text
    )
  end

  def parse_list(text)
    return [] if text.blank?
    text.split(",").map(&:strip).reject(&:blank?)
  end
end
