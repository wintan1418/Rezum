class Subscription < ApplicationRecord
  belongs_to :user

  validates :paystack_subscription_code, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active trialing past_due canceled unpaid incomplete] }
  validates :plan_id, presence: true

  enum :status, {
    active: "active",
    trialing: "trialing",
    past_due: "past_due",
    canceled: "canceled",
    unpaid: "unpaid",
    incomplete: "incomplete"
  }

  scope :active_subscriptions, -> { where(status: %w[active trialing]) }
  scope :canceled_subscriptions, -> { where(status: "canceled") }

  # Paystack plan codes — set via env vars on Hatchbox
  PLAN_CODES = {
    "price_monthly_pro" => ENV["PAYSTACK_PLAN_MONTHLY_PRO"],
    "price_annual_pro" => ENV["PAYSTACK_PLAN_ANNUAL_PRO"],
    "price_monthly_premium" => ENV["PAYSTACK_PLAN_MONTHLY_PREMIUM"],
    "price_annual_premium" => ENV["PAYSTACK_PLAN_ANNUAL_PREMIUM"]
  }.freeze

  def active?
    status.in?(%w[active trialing]) && current_period_end&.future?
  end

  def trialing?
    status == "trialing" && trial_end&.future?
  end

  def expired?
    current_period_end&.past?
  end

  def days_until_renewal
    return 0 unless current_period_end
    [ (current_period_end.to_date - Date.current).to_i, 0 ].max
  end

  def plan_name
    case plan_id
    when "price_monthly_pro" then "Monthly Pro"
    when "price_annual_pro" then "Annual Pro"
    when "price_monthly_premium" then "Monthly Premium"
    when "price_annual_premium" then "Annual Premium"
    else plan_id&.humanize || "Unknown Plan"
    end
  end

  def plan_price
    case plan_id
    when "price_monthly_pro" then 29
    when "price_annual_pro" then 290
    when "price_monthly_premium" then 59
    when "price_annual_premium" then 590
    else 0
    end
  end

  def billing_cycle
    case plan_id
    when "price_monthly_pro", "price_monthly_premium" then "monthly"
    when "price_annual_pro", "price_annual_premium" then "annual"
    else "unknown"
    end
  end

  def premium?
    plan_id.to_s.include?("premium")
  end

  # Sync from Paystack
  def sync_from_paystack!
    return unless paystack_subscription_code

    data = PaystackService.fetch_subscription(paystack_subscription_code)
    return unless data

    new_status = case data["status"]
    when "active" then "active"
    when "non-renewing" then "canceled"
    when "attention" then "past_due"
    else data["status"]
    end

    attrs = { status: new_status }
    attrs[:current_period_start] = Time.parse(data["createdAt"]) if data["createdAt"]
    if data["next_payment_date"]
      attrs[:current_period_end] = Time.parse(data["next_payment_date"])
    end

    update!(attrs)
  end

  # Cancel at period end (disable subscription)
  def cancel_at_period_end!
    return unless paystack_subscription_code

    PaystackService.disable_subscription(
      code: paystack_subscription_code,
      token: email_token
    )

    update!(cancel_at_period_end: true)
  end

  # Reactivate subscription
  def reactivate!
    return unless paystack_subscription_code && cancel_at_period_end?

    PaystackService.enable_subscription(
      code: paystack_subscription_code,
      token: email_token
    )

    update!(cancel_at_period_end: false)
  end

  private

  def email_token
    user.email
  end
end
