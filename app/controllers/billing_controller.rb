class BillingController < ApplicationController
  before_action :authenticate_user!

  # Pricing tiers: { credits => base price in NGN kobo }
  PRICING_NGN = {
    10  => 5_000_00,   # ₦5,000
    50  => 20_000_00,  # ₦20,000
    100 => 35_000_00   # ₦35,000
  }.freeze

  # Countries that pay in NGN
  NGN_COUNTRIES = %w[NG].freeze

  # International markup (10%)
  INTERNATIONAL_MARKUP = 1.1

  def index
    @subscription = current_user.current_subscription
    @payments = current_user.payments.where(status: %w[success pending]).recent.limit(10)
    @total_spent = current_user.total_spent
    @credits_remaining = current_user.credits_remaining
    @pricing = pricing_for_user(current_user)
  end

  def history
    @payments = current_user.payments.recent.includes(:user)
    @payments = @payments.page(params[:page]).per(20) if defined?(Kaminari)
    @pricing = pricing_for_user(current_user)
  end

  def purchase_credits
    credits = params[:credits].to_i

    if credits <= 0
      return redirect_to billing_index_path, alert: "Invalid credit amount"
    end

    pricing = pricing_for_user(current_user)
    tier = pricing[:tiers].find { |t| t[:credits] == credits }
    amount = tier ? tier[:amount_kobo] : (credits * pricing[:per_credit_kobo])
    currency = pricing[:currency]

    begin
      result = Payment.create_paystack_transaction(
        user: current_user,
        amount_cents: amount,
        currency: currency,
        description: "#{credits} Credits Purchase",
        credits: credits,
        callback_url: verify_payment_billing_index_url
      )

      ahoy.track "credit_purchase", payment_id: result[:payment].id, credits: credits, amount: amount
      redirect_to result[:authorization_url], allow_other_host: true
    rescue PaystackService::PaystackError => e
      Rails.logger.error "Paystack error: #{e.message}"
      redirect_to billing_index_path, alert: "Payment failed: #{e.message}"
    rescue => e
      Rails.logger.error "Payment failed: #{e.class}: #{e.message}"
      redirect_to billing_index_path, alert: "Payment failed. Please try again later."
    end
  end

  # Paystack redirects here after payment
  def verify_payment
    reference = params[:reference] || params[:trxref]

    if reference.blank?
      return redirect_to billing_index_path, alert: "Invalid payment reference"
    end

    payment = current_user.payments.find_by(paystack_reference: reference)

    if payment.nil?
      return redirect_to billing_index_path, alert: "Payment not found"
    end

    begin
      payment.verify_with_paystack!

      if payment.successful?
        redirect_to billing_path(payment), notice: "Payment successful! #{payment.credits_purchased} credits added."
      else
        redirect_to billing_path(payment), alert: "Payment was not successful. Status: #{payment.status.humanize}"
      end
    rescue => e
      Rails.logger.error "Payment verification failed: #{e.message}"
      redirect_to billing_path(payment), alert: "Could not verify payment. Please contact support."
    end
  end

  def show
    @payment = current_user.payments.find(params[:id])
  end

  private

  def detected_currency
    @detected_currency ||= CountryDetectionService.new(request, current_user).detect_currency
  end

  def ngn_user?(user)
    NGN_COUNTRIES.include?(user.country_code&.upcase) ||
      user.currency == "NGN" ||
      detected_currency == "NGN"
  end

  def pricing_for_user(user)
    if ngn_user?(user)
      {
        currency: "NGN",
        symbol: "\u20A6",
        tiers: [
          { credits: 5,   amount_kobo: 1_500_00,  display: "1,500",  per_credit: "300", label: "Starter", badge: "Try It" },
          { credits: 10,  amount_kobo: 5_000_00,  display: "5,000",  per_credit: "500", label: "Standard" },
          { credits: 50,  amount_kobo: 20_000_00, display: "20,000", per_credit: "400", label: "Pro Pack", badge: "Most Popular" },
          { credits: 100, amount_kobo: 35_000_00, display: "35,000", per_credit: "350", label: "Mega Pack", badge: "Best Value" }
        ],
        per_credit_kobo: 500_00
      }
    else
      {
        currency: "NGN",
        symbol: "$",
        display_currency: "USD",
        tiers: [
          { credits: 5,   amount_kobo: 1_650_00,  display: "3",   per_credit: "0.60", label: "Starter", badge: "Try It" },
          { credits: 10,  amount_kobo: 5_500_00,  display: "5",   per_credit: "0.50", label: "Standard" },
          { credits: 50,  amount_kobo: 22_000_00, display: "20",  per_credit: "0.40", label: "Pro Pack", badge: "Most Popular" },
          { credits: 100, amount_kobo: 38_500_00, display: "35",  per_credit: "0.35", label: "Mega Pack", badge: "Best Value" }
        ],
        per_credit_kobo: 550_00
      }
    end
  end
end
