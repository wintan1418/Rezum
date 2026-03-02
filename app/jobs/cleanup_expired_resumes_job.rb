class CleanupExpiredResumesJob < ApplicationJob
  queue_as :default

  def perform
    expired = Resume.where("expires_at IS NOT NULL AND expires_at < ?", Time.current)
    count = expired.count
    expired.destroy_all
    Rails.logger.info "CleanupExpiredResumesJob: Deleted #{count} expired resumes"
  end
end
