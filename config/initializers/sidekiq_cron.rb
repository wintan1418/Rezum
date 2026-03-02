if defined?(Sidekiq::Cron) && Rails.application.config.respond_to?(:after_initialize)
  Rails.application.config.after_initialize do
    begin
      Sidekiq::Cron::Job.create(
        name: "Email Drip Campaign - daily at 9am UTC",
        cron: "0 9 * * *",
        class: "EmailDripCampaignJob"
      )

      Sidekiq::Cron::Job.create(
        name: "Job Scraper - every hour",
        cron: "0 * * * *",
        class: "ScheduledJobScraperJob"
      )

      Sidekiq::Cron::Job.create(
        name: "Cleanup Expired Resumes - daily at midnight",
        cron: "0 0 * * *",
        class: "CleanupExpiredResumesJob"
      )
    rescue => e
      Rails.logger.warn "Sidekiq Cron setup skipped: #{e.message}"
    end
  end
end
