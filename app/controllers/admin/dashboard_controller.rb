module Admin
  class DashboardController < BaseController
    def index
      @total_users = Rails.cache.fetch("admin:total_users", expires_in: 1.hour) { User.count }
      @new_users_this_week = Rails.cache.fetch("admin:new_users_week", expires_in: 30.minutes) { User.where("created_at >= ?", 1.week.ago).count }
      @total_resumes = Rails.cache.fetch("admin:total_resumes", expires_in: 1.hour) { Resume.count }
      @total_cover_letters = Rails.cache.fetch("admin:total_cover_letters", expires_in: 1.hour) { CoverLetter.count }
      @active_subscribers = Rails.cache.fetch("admin:active_subscribers", expires_in: 30.minutes) { Subscription.where(status: :active).select(:user_id).distinct.count }
      @total_revenue = Rails.cache.fetch("admin:total_revenue", expires_in: 5.minutes) { Payment.where(status: "success").sum(:amount_cents) / 100.0 }
      @revenue_this_month = Rails.cache.fetch("admin:revenue_month", expires_in: 5.minutes) { Payment.where(status: "success").where("created_at >= ?", Time.current.beginning_of_month).sum(:amount_cents) / 100.0 }

      @user_growth = Rails.cache.fetch("admin:user_growth", expires_in: 30.minutes) { User.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s) }
      @recent_users = User.recent.limit(10)
      @recent_payments = Payment.where(status: "success").includes(:user).order(created_at: :desc).limit(10)
      @resume_growth = Rails.cache.fetch("admin:resume_growth", expires_in: 30.minutes) { Resume.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s) }
    end
  end
end
