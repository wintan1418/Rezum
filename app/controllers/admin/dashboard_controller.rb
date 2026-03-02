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
    end
  end
end
