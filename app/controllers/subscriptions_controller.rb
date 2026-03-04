class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription, only: [ :show, :cancel, :reactivate, :destroy ]

  # Countries that pay in NGN
  NGN_COUNTRIES = %w[NG].freeze

  def new
    @subscription = current_user.subscriptions.build
    @is_ngn = ngn_user?(current_user)
    @symbol = @is_ngn ? "\u20A6" : "$"
    @plans = plans_for_user
  end

  def create
    plan_id = params[:plan_id]
    return redirect_to new_subscription_path, alert: "Please select a plan" unless plan_id

    # Map plan_id to Paystack plan code and amount
    plan_config = plan_details(plan_id)
    return redirect_to new_subscription_path, alert: "Invalid plan selected" unless plan_config

    begin
      current_user.create_paystack_customer! unless current_user.paystack_customer_code.present?

      # Initialize transaction with plan for recurring billing
      paystack_plan_code = Subscription::PLAN_CODES[plan_id]
      unless paystack_plan_code.present?
        Rails.logger.error "Missing Paystack plan code for #{plan_id}. Set PAYSTACK_PLAN_* env vars."
        return redirect_to new_subscription_path, alert: "Plan configuration error. Please contact support."
      end

      result = PaystackService.initialize_transaction(
        email: current_user.email,
        amount: plan_config[:amount],
        callback_url: verify_subscription_subscriptions_url,
        metadata: {
          user_id: current_user.id,
          plan_id: plan_id,
          subscription: true
        },
        plan: paystack_plan_code
      )

      ahoy.track "subscription_start", plan_id: plan_id

      redirect_to result["authorization_url"], allow_other_host: true
    rescue PaystackService::PaystackError => e
      Rails.logger.error "Subscription creation failed: #{e.message}"
      redirect_to new_subscription_path, alert: "Subscription failed: #{e.message}"
    rescue => e
      Rails.logger.error "Subscription creation failed: #{e.class}: #{e.message}"
      redirect_to new_subscription_path, alert: "Subscription failed. Please try again."
    end
  end

  # Paystack redirects here after subscription payment
  def verify_subscription
    reference = params[:reference] || params[:trxref]

    if reference.blank?
      return redirect_to new_subscription_path, alert: "Invalid payment reference"
    end

    begin
      data = PaystackService.verify_transaction(reference)

      if data["status"] == "success"
        plan_id = data.dig("metadata", "plan_id") || "price_monthly_pro"

        # Find or create the subscription
        sub_code = data.dig("plan_object", "subscriptions", 0, "subscription_code") ||
                   "sub_#{reference}"

        subscription = current_user.subscriptions.find_or_initialize_by(paystack_subscription_code: sub_code)
        subscription.assign_attributes(
          status: "active",
          plan_id: plan_id,
          current_period_start: Time.current,
          current_period_end: calculate_period_end(plan_id)
        )
        subscription.save!

        redirect_to subscription_path(subscription), notice: "Subscription activated successfully!"
      else
        redirect_to new_subscription_path, alert: "Payment was not successful. Status: #{data['status']}"
      end
    rescue => e
      Rails.logger.error "Subscription verification failed: #{e.message}"
      redirect_to new_subscription_path, alert: "Could not verify subscription. Please contact support."
    end
  end

  def show; end

  def cancel
    begin
      @subscription.cancel_at_period_end!
      redirect_to subscription_path(@subscription), notice: "Subscription will be canceled at the end of the current period."
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to cancel: #{e.message}"
    end
  end

  def reactivate
    begin
      @subscription.reactivate!
      redirect_to subscription_path(@subscription), notice: "Subscription reactivated!"
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to reactivate: #{e.message}"
    end
  end

  def destroy
    begin
      PaystackService.disable_subscription(
        code: @subscription.paystack_subscription_code,
        token: current_user.email
      )
      @subscription.update!(status: "canceled")
      redirect_to billing_index_path, notice: "Subscription canceled immediately."
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to cancel: #{e.message}"
    end
  end

  private

  def set_subscription
    @subscription = current_user.subscriptions.find(params[:id])
  end

  def detected_currency
    @detected_currency ||= CountryDetectionService.new(request, current_user).detect_currency
  end

  def ngn_user?(user)
    NGN_COUNTRIES.include?(user.country_code&.upcase) ||
      user.currency == "NGN" ||
      detected_currency == "NGN"
  end

  def plans_for_user
    pro_features = [
      "Unlimited resume optimizations",
      "Unlimited cover letters",
      "ATS scoring & keyword extraction",
      "AI Resume Builder (from scratch)",
      "5 professional templates",
      "PDF & DOCX downloads",
      "Job Application Tracker",
      "Priority support"
    ]

    premium_features = [
      "Everything in Pro, plus:",
      "Unlimited AI Resume Builder",
      "AI Interview Prep (STAR method)",
      "LinkedIn Profile Optimization",
      "Automated Job Scraper",
      "AI job matching & scoring",
      "Priority AI models (GPT-4, Claude)",
      "Early access to new features"
    ]

    [
      {
        id: "price_monthly_pro",
        name: "Monthly Pro",
        price_label: @is_ngn ? "#{@symbol}29,000" : "#{@symbol}29",
        interval: "month",
        tier: "pro",
        features: pro_features
      },
      {
        id: "price_annual_pro",
        name: "Annual Pro",
        price_label: @is_ngn ? "#{@symbol}290,000" : "#{@symbol}290",
        interval: "year",
        tier: "pro",
        features: pro_features + [ "2 months free" ]
      },
      {
        id: "price_monthly_premium",
        name: "Monthly Premium",
        price_label: @is_ngn ? "#{@symbol}59,000" : "#{@symbol}59",
        interval: "month",
        tier: "premium",
        features: premium_features
      },
      {
        id: "price_annual_premium",
        name: "Annual Premium",
        price_label: @is_ngn ? "#{@symbol}590,000" : "#{@symbol}590",
        interval: "year",
        tier: "premium",
        features: premium_features + [ "2 months free" ]
      }
    ]
  end

  def plan_details(plan_id)
    {
      "price_monthly_pro" => { amount: 29_000_00, interval: "monthly" },
      "price_annual_pro" => { amount: 290_000_00, interval: "annually" },
      "price_monthly_premium" => { amount: 59_000_00, interval: "monthly" },
      "price_annual_premium" => { amount: 590_000_00, interval: "annually" }
    }[plan_id]
  end

  def calculate_period_end(plan_id)
    case plan_id
    when "price_monthly_pro", "price_monthly_premium"
      1.month.from_now
    when "price_annual_pro", "price_annual_premium"
      1.year.from_now
    else
      1.month.from_now
    end
  end
end
