class BillingController < ApplicationController
  before_action :authenticate_user!

  def index
    @subscription = current_user.current_subscription
    @payments = current_user.payments.recent.limit(10)
    @total_spent = current_user.total_spent
    @credits_remaining = current_user.credits_remaining
  end

  def history
    @payments = current_user.payments.recent.includes(:user)
    @payments = @payments.page(params[:page]).per(20) if defined?(Kaminari)
  end

  def purchase_credits
    credits = params[:credits].to_i

    if credits <= 0
      return redirect_to billing_index_path, alert: "Invalid credit amount"
    end

    # Pricing in kobo (NGN smallest unit). Adjust amounts as needed.
    amount = case credits
    when 10 then 500_00   # ₦500
    when 35 then 1500_00  # ₦1,500
    when 75 then 3000_00  # ₦3,000
    else credits * 50_00  # ₦50 per credit fallback
    end

    begin
      result = Payment.create_paystack_transaction(
        user: current_user,
        amount_cents: amount,
        currency: "NGN",
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
end
