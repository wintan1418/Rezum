module Admin
  class DashboardController < BaseController
    # NGN to USD approximate rate for display toggle
    NGN_USD_RATE = 1_600

    def index
      # === Core Stats ===
      @total_users = Rails.cache.fetch("admin:total_users", expires_in: 30.minutes) { User.count }
      @new_users_this_week = Rails.cache.fetch("admin:new_users_week", expires_in: 10.minutes) { User.where("created_at >= ?", 1.week.ago).count }
      @total_resumes = Rails.cache.fetch("admin:total_resumes", expires_in: 30.minutes) { Resume.count }
      @total_cover_letters = Rails.cache.fetch("admin:total_cover_letters", expires_in: 30.minutes) { CoverLetter.count }
      @active_subscribers = Rails.cache.fetch("admin:active_subscribers", expires_in: 10.minutes) { Subscription.where(status: :active).select(:user_id).distinct.count }

      # === Revenue Stats (all in NGN kobo internally) ===
      @total_revenue_kobo = Rails.cache.fetch("admin:total_revenue_kobo", expires_in: 5.minutes) { Payment.successful.sum(:amount_cents) }
      @revenue_this_month_kobo = Rails.cache.fetch("admin:revenue_month_kobo", expires_in: 5.minutes) {
        Payment.successful.where("created_at >= ?", Time.current.beginning_of_month).sum(:amount_cents)
      }
      @revenue_last_month_kobo = Rails.cache.fetch("admin:revenue_last_month_kobo", expires_in: 1.hour) {
        Payment.successful.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).sum(:amount_cents)
      }
      @revenue_today_kobo = Rails.cache.fetch("admin:revenue_today_kobo", expires_in: 2.minutes) {
        Payment.successful.where("created_at >= ?", Time.current.beginning_of_day).sum(:amount_cents)
      }

      # === Revenue Breakdown ===
      @credit_revenue_kobo = Rails.cache.fetch("admin:credit_revenue_kobo", expires_in: 5.minutes) {
        Payment.successful.credit_purchases.sum(:amount_cents)
      }
      @subscription_revenue_kobo = Rails.cache.fetch("admin:sub_revenue_kobo", expires_in: 5.minutes) {
        @total_revenue_kobo - @credit_revenue_kobo
      }
      @total_credits_sold = Rails.cache.fetch("admin:total_credits_sold", expires_in: 5.minutes) {
        Payment.successful.credit_purchases.sum(:credits_purchased)
      }

      # === Subscription Breakdown ===
      @subscription_by_plan = Rails.cache.fetch("admin:sub_by_plan", expires_in: 10.minutes) {
        Subscription.where(status: :active).group(:plan_id).count
      }

      # === Revenue by Country (top 10) ===
      @revenue_by_country = Rails.cache.fetch("admin:revenue_by_country", expires_in: 15.minutes) {
        Payment.successful.joins(:user)
          .group("COALESCE(users.country_code, 'Unknown')")
          .sum(:amount_cents)
          .sort_by { |_, v| -v }
          .first(10)
      }

      # === User Acquisition Sources (top 10 referring domains) ===
      @traffic_sources = Rails.cache.fetch("admin:traffic_sources", expires_in: 30.minutes) {
        Ahoy::Visit.where.not(referring_domain: [nil, ""])
          .where("started_at >= ?", 30.days.ago)
          .group(:referring_domain)
          .count
          .sort_by { |_, v| -v }
          .first(10)
      }

      # === Users by Country (top 10) ===
      @users_by_country = Rails.cache.fetch("admin:users_by_country", expires_in: 30.minutes) {
        User.where.not(country_code: nil)
          .group(:country_code)
          .count
          .sort_by { |_, v| -v }
          .first(10)
      }

      # === Charts ===
      @user_growth = Rails.cache.fetch("admin:user_growth", expires_in: 30.minutes) {
        User.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s)
      }
      @revenue_growth = Rails.cache.fetch("admin:revenue_growth", expires_in: 10.minutes) {
        Payment.successful.group_by_day(:created_at, last: 30).sum(:amount_cents).transform_keys(&:to_s).transform_values { |v| v / 100.0 }
      }
      @resume_growth = Rails.cache.fetch("admin:resume_growth", expires_in: 30.minutes) {
        Resume.group_by_day(:created_at, last: 30).count.transform_keys(&:to_s)
      }

      # === Payment Conversion ===
      @payment_funnel = Rails.cache.fetch("admin:payment_funnel", expires_in: 10.minutes) {
        Payment.group(:status).count
      }

      # === Recent Activity ===
      @recent_users = User.recent.limit(10)
      @recent_payments = Payment.successful.includes(:user).order(created_at: :desc).limit(10)
    end

    def report
      respond_to do |format|
        format.csv do
          report_type = params[:type] || "revenue"
          csv_data = generate_report(report_type)
          send_data csv_data, filename: "rezumfit_#{report_type}_#{Date.current}.csv", type: "text/csv"
        end
      end
    end

    private

    def generate_report(type)
      case type
      when "revenue"
        revenue_report
      when "users"
        users_report
      when "subscriptions"
        subscriptions_report
      else
        revenue_report
      end
    end

    def revenue_report
      payments = Payment.successful.includes(:user).order(created_at: :desc)

      CSV.generate(headers: true) do |csv|
        csv << ["Date", "User", "Email", "Country", "Description", "Amount (NGN)", "Amount (USD est.)", "Credits", "Status"]
        payments.each do |p|
          csv << [
            p.created_at.strftime("%Y-%m-%d %H:%M"),
            p.user.full_name,
            p.user.email,
            p.user.country_code || "Unknown",
            p.description_display,
            p.amount_cents / 100.0,
            (p.amount_cents / 100.0 / NGN_USD_RATE).round(2),
            p.credits_purchased,
            p.status
          ]
        end
      end
    end

    def users_report
      users = User.includes(:payments, :resumes, :subscriptions).order(created_at: :desc)

      CSV.generate(headers: true) do |csv|
        csv << ["Name", "Email", "Country", "Currency", "Credits", "Resumes", "Total Spent (NGN)", "Subscriber", "Joined"]
        users.each do |u|
          csv << [
            u.full_name,
            u.email,
            u.country_code || "Unknown",
            u.currency || "N/A",
            u.credits_remaining,
            u.resumes.size,
            u.payments.successful.sum(:amount_cents) / 100.0,
            u.has_active_subscription? ? "Yes" : "No",
            u.created_at.strftime("%Y-%m-%d")
          ]
        end
      end
    end

    def subscriptions_report
      subs = Subscription.includes(:user).order(created_at: :desc)

      CSV.generate(headers: true) do |csv|
        csv << ["User", "Email", "Plan", "Status", "Started", "Period End", "Cancel at End"]
        subs.each do |s|
          csv << [
            s.user.full_name,
            s.user.email,
            s.plan_id,
            s.status,
            s.created_at.strftime("%Y-%m-%d"),
            s.current_period_end&.strftime("%Y-%m-%d"),
            s.cancel_at_period_end? ? "Yes" : "No"
          ]
        end
      end
    end
  end
end
