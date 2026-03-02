class EmailDripCampaignJob < ApplicationJob
  queue_as :mailers

  def perform
    send_trial_ending_reminders
    send_low_credit_alerts
    send_re_engagement_emails
    send_weekly_tips
  end

  private

  def send_trial_ending_reminders
    User.trial.where(trial_ends_at: 2.days.from_now..4.days.from_now).find_each do |user|
      next unless user.subscribed_to_emails?
      UserMailer.trial_ending_reminder(user, days_remaining: 3).deliver_later
    end

    User.trial.where(trial_ends_at: Time.current..2.days.from_now).find_each do |user|
      next unless user.subscribed_to_emails?
      UserMailer.trial_ending_reminder(user, days_remaining: 1).deliver_later
    end
  end

  def send_low_credit_alerts
    User.free.where(credits_remaining: 1).where("last_email_sent_at IS NULL OR last_email_sent_at < ?", 3.days.ago).find_each do |user|
      next unless user.subscribed_to_emails?
      UserMailer.credits_low(user).deliver_later
      user.update_column(:last_email_sent_at, Time.current)
    end

    User.free.where(credits_remaining: 0).where("last_email_sent_at IS NULL OR last_email_sent_at < ?", 7.days.ago).find_each do |user|
      next unless user.subscribed_to_emails?
      UserMailer.credits_exhausted(user).deliver_later
      user.update_column(:last_email_sent_at, Time.current)
    end
  end

  def send_re_engagement_emails
    [ 7, 14, 30 ].each do |days|
      User.where(last_active_at: (days + 1).days.ago..(days).days.ago)
          .where("last_email_sent_at IS NULL OR last_email_sent_at < ?", 7.days.ago)
          .find_each do |user|
        next unless user.subscribed_to_emails?
        UserMailer.re_engagement(user, inactive_days: days).deliver_later
        user.update_column(:last_email_sent_at, Time.current)
      end
    end
  end

  def send_weekly_tips
    User.where(marketing_consent: true)
        .where(unsubscribed_at: nil)
        .where("created_at < ?", 1.week.ago)
        .where("last_email_sent_at IS NULL OR last_email_sent_at < ?", 6.days.ago)
        .find_each do |user|
      tip_number = ((Date.current - user.created_at.to_date).to_i / 7)
      UserMailer.weekly_tips(user, tip_number: tip_number).deliver_later
      user.update_column(:last_email_sent_at, Time.current)
    end
  end
end
