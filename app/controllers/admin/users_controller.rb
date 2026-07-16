module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :toggle_admin, :toggle_disable, :gift_credits, :grant_subscription, :revoke_subscription ]

    COMPLIMENTARY_PLANS = {
      "pro" => "price_monthly_pro",
      "premium" => "price_monthly_premium"
    }.freeze
    COMPLIMENTARY_DURATIONS = [ 30, 90, 365 ].freeze

    def index
      @users = User.recent.includes(:subscriptions)
      @users = @users.search(params[:q]) if params[:q].present?

      case params[:filter]
      when "subscribers"
        @users = @users.subscribers
      when "free"
        @users = @users.where.not(id: Subscription.where(status: :active).select(:user_id))
      when "disabled"
        @users = @users.where.not(disabled_at: nil)
      when "admins"
        @users = @users.admins
      end

      @users = @users.page(params[:page]) if @users.respond_to?(:page)
      @users = @users.limit(50) unless @users.respond_to?(:page)
    end

    def show
      @resumes = @user.resumes.order(created_at: :desc).limit(10)
      @cover_letters = @user.cover_letters.order(created_at: :desc).limit(10)
      @payments = @user.payments.order(created_at: :desc).limit(10)
    end

    def toggle_admin
      if @user == current_user
        return redirect_to admin_user_path(@user), alert: "You cannot change your own admin access."
      end

      @user.update(admin: !@user.admin?)
      redirect_to admin_user_path(@user), notice: "#{@user.full_name} is now #{@user.admin? ? 'an admin' : 'a regular user'}."
    end

    # Complimentary access: creates a comp_ subscription so the user passes
    # has_active_subscription?/has_premium_subscription? without touching
    # Paystack. Granting again replaces any existing comp subscription.
    def grant_subscription
      plan_id = COMPLIMENTARY_PLANS[params[:plan].to_s]
      days = params[:duration].to_i

      unless plan_id && COMPLIMENTARY_DURATIONS.include?(days)
        return redirect_to admin_user_path(@user), alert: "Pick a valid plan and duration."
      end

      cancel_complimentary_subscriptions!

      @user.subscriptions.create!(
        paystack_subscription_code: "comp_#{SecureRandom.hex(8)}",
        status: "active",
        plan_id: plan_id,
        current_period_start: Time.current,
        current_period_end: days.days.from_now
      )

      redirect_to admin_user_path(@user),
        notice: "#{@user.full_name} is now on #{params[:plan].capitalize} (complimentary) for #{days} days."
    end

    def revoke_subscription
      revoked = cancel_complimentary_subscriptions!

      if revoked.positive?
        redirect_to admin_user_path(@user), notice: "Complimentary access revoked for #{@user.full_name}."
      else
        redirect_to admin_user_path(@user), alert: "No complimentary subscription to revoke — paid subscriptions must be cancelled through Paystack."
      end
    end

    def toggle_disable
      if @user.disabled?
        @user.update(disabled_at: nil)
        redirect_to admin_user_path(@user), notice: "#{@user.full_name} has been enabled."
      else
        @user.update(disabled_at: Time.current)
        redirect_to admin_user_path(@user), notice: "#{@user.full_name} has been disabled."
      end
    end

    def gift_credits
      credits = params[:credits].to_i
      reason = params[:reason].to_s.strip

      if credits <= 0 || credits > 500
        return redirect_to admin_user_path(@user), alert: "Credits must be between 1 and 500."
      end

      @user.increment!(:credits_remaining, credits)
      UserMailer.credits_gifted(@user, credits: credits, reason: reason).deliver_later

      redirect_to admin_user_path(@user), notice: "#{credits} credits gifted to #{@user.full_name}. Email notification sent."
    end

    private

    def cancel_complimentary_subscriptions!
      @user.subscriptions
           .where("paystack_subscription_code LIKE 'comp_%'")
           .where(status: %w[active trialing])
           .update_all(status: "canceled", current_period_end: Time.current, updated_at: Time.current)
    end

    def set_user
      @user = User.find(params[:id])
    end
  end
end
