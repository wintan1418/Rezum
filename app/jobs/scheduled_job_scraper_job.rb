class ScheduledJobScraperJob < ApplicationJob
  queue_as :default

  def perform
    # Find all premium users with enabled scraper settings that are due
    JobScraperSetting.includes(:user).where(enabled: true).find_each do |settings|
      next unless settings.user.has_premium_subscription?
      next unless settings.due_for_scrape?

      ScrapeJobsJob.perform_later(settings.user_id)
    end
  end
end
