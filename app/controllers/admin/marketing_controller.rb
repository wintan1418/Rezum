module Admin
  class MarketingController < BaseController
    def index
      @segments = {
        all: User.where(unsubscribed_at: nil).count,
        free: User.where(unsubscribed_at: nil).where.not(id: Subscription.where(status: [ :active, :trialing ]).select(:user_id)).count,
        trial_ending: User.where(unsubscribed_at: nil).where(trial_ends_at: 3.days.from_now..7.days.from_now).count,
        inactive: User.where(unsubscribed_at: nil).where("last_active_at < ?", 7.days.ago).count,
        low_credits: User.where(unsubscribed_at: nil).where(credits_remaining: 0..1).count,
        subscribers: Subscription.where(status: [ :active, :trialing ]).select(:user_id).distinct.count
      }
    end

    def send_campaign
      campaign = params[:campaign]
      count = 0

      case campaign
      when "upgrade_nudge"
        free_users.find_each do |user|
          UserMailer.upgrade_nudge(user).deliver_later
          count += 1
        end

      when "trial_ending"
        trial_ending_users.find_each do |user|
          days = ((user.trial_ends_at - Time.current) / 1.day).ceil
          UserMailer.trial_ending_reminder(user, days_remaining: days).deliver_later
          count += 1
        end

      when "credits_low"
        low_credit_users.find_each do |user|
          UserMailer.credits_low(user).deliver_later
          count += 1
        end

      when "re_engagement"
        inactive_users.find_each do |user|
          days = ((Time.current - user.last_active_at) / 1.day).to_i
          UserMailer.re_engagement(user, inactive_days: days).deliver_later
          count += 1
        end

      when "weekly_tips"
        tip_number = Date.current.cweek % 5
        eligible_users.find_each do |user|
          UserMailer.weekly_tips(user, tip_number: tip_number).deliver_later
          count += 1
        end

      when "feature_announcement"
        subject = params[:announcement_subject].presence
        body = params[:announcement_body].presence

        unless subject && body
          redirect_to admin_marketing_index_path, alert: "Subject and body are required for announcements."
          return
        end

        eligible_users.find_each do |user|
          UserMailer.feature_announcement(user, subject: subject, body: body).deliver_later
          count += 1
        end

      else
        redirect_to admin_marketing_index_path, alert: "Unknown campaign."
        return
      end

      redirect_to admin_marketing_index_path, notice: "Queued #{count} emails for \"#{campaign.humanize}\". Sending via background jobs."
    end

    private

    def eligible_users
      User.where(unsubscribed_at: nil)
    end

    def free_users
      eligible_users.where.not(id: Subscription.where(status: [ :active, :trialing ]).select(:user_id))
    end

    def trial_ending_users
      eligible_users.where(trial_ends_at: 3.days.from_now..7.days.from_now)
    end

    def inactive_users
      eligible_users.where("last_active_at < ?", 7.days.ago)
    end

    def low_credit_users
      eligible_users.where(credits_remaining: 0..1)
    end
  end
end
