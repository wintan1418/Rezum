class FollowUpReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    JobApplication.needs_follow_up.includes(:user).find_each do |application|
      next unless application.user.subscribed_to_emails?

      UserMailer.follow_up_reminder(application.user, application).deliver_later
    end
  end
end
