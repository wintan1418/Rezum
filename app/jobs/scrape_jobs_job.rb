class ScrapeJobsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    user = User.find(user_id)
    settings = user.job_scraper_setting

    return unless settings&.enabled?
    return unless user.has_premium_subscription?

    user.update_column(:scraping_in_progress, true)

    service = JobScraperService.new(user: user, settings: settings)
    result = service.scrape

    if result[:success]
      Rails.logger.info "Job scraping completed for user #{user_id}: found #{result[:found]}, saved #{result[:saved]}"
    else
      Rails.logger.error "Job scraping failed for user #{user_id}: #{result[:error]}"
    end
  ensure
    user&.update_column(:scraping_in_progress, false)
  end
end
