module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @new_users_this_week = User.where("created_at >= ?", 1.week.ago).count
      @total_resumes = Resume.count
      @total_cover_letters = CoverLetter.count
      @active_subscribers = Subscription.where(status: :active).select(:user_id).distinct.count
      @total_revenue = Payment.where(status: "success").sum(:amount_cents) / 100.0

      @user_growth = User.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s)
      @recent_users = User.recent.limit(10)
      @resume_growth = Resume.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s)

      @available_emails = {
        "rebrand_notification" => "Rebrand Notification (ReZum → RezumFit)",
        "re_engagement" => "Re-engagement (Come back!)",
        "weekly_tips" => "Weekly Career Tips"
      }
    end

    def send_bulk_email
      email_type = params[:email_type]
      users = User.where(unsubscribed_at: nil)
      count = 0

      case email_type
      when "rebrand_notification"
        users.find_each do |user|
          UserMailer.rebrand_notification(user).deliver_later
          count += 1
        end
      when "re_engagement"
        users.where("last_sign_in_at < ?", 7.days.ago).find_each do |user|
          UserMailer.re_engagement(user, inactive_days: ((Time.current - user.last_sign_in_at) / 1.day).to_i).deliver_later
          count += 1
        end
      when "weekly_tips"
        tip_number = (Date.current.cweek % 5)
        users.find_each do |user|
          UserMailer.weekly_tips(user, tip_number: tip_number).deliver_later
          count += 1
        end
      else
        redirect_to admin_root_path, alert: "Unknown email type."
        return
      end

      redirect_to admin_root_path, notice: "Queued #{count} emails (#{email_type.humanize}). They'll be sent via background jobs."
    end
  end
end
