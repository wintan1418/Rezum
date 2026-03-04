class Payment < ApplicationRecord
  belongs_to :user

  validates :paystack_reference, presence: true, uniqueness: true
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: %w[pending success failed abandoned canceled] }
  validates :credits_purchased, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  monetize :amount_cents

  enum :status, {
    pending: "pending",
    success: "success",
    failed: "failed",
    abandoned: "abandoned",
    canceled: "canceled"
  }

  scope :successful, -> { where(status: "success") }
  scope :recent, -> { order(created_at: :desc) }
  scope :credit_purchases, -> { where.not(credits_purchased: nil) }

  def successful?
    status == "success"
  end

  def failed?
    status.in?(%w[failed canceled abandoned])
  end

  def pending?
    status == "pending"
  end

  def amount_display
    naira_amount = amount_cents / 100.0
    formatted = ActiveSupport::NumberHelper.number_to_delimited(naira_amount.to_i)
    "#{currency_symbol}#{formatted}"
  end

  def currency_symbol
    case currency.to_s.upcase
    when "NGN" then "\u20A6"
    when "USD" then "$"
    when "GHS" then 'GH\u20B5'
    when "ZAR" then "R"
    when "KES" then "KSh"
    when "EUR" then "\u20AC"
    when "GBP" then "\u00A3"
    else "#{currency.upcase} "
    end
  end

  def description_display
    return description if description.present?

    if credits_purchased.present?
      "#{credits_purchased} Credits Purchase"
    else
      "Payment"
    end
  end

  # Verify payment with Paystack
  def verify_with_paystack!
    return unless paystack_reference

    already_successful = successful?

    data = PaystackService.verify_transaction(paystack_reference)

    new_status = case data["status"]
    when "success" then "success"
    when "failed" then "failed"
    when "abandoned" then "abandoned"
    else "pending"
    end

    update!(
      status: new_status,
      amount_cents: data["amount"],
      currency: data["currency"]
    )

    # Only add credits if this is the first time we see success
    # (webhook may have already processed it)
    if successful? && !already_successful && credits_purchased.present?
      user.add_credits(credits_purchased)
      UserMailer.payment_confirmation(user, self).deliver_later
    end
  end

  # Initialize a Paystack transaction for credit purchase
  def self.create_paystack_transaction(user:, amount_cents:, currency: "NGN", description: nil, credits: nil, callback_url: nil)
    user.create_paystack_customer! unless user.paystack_customer_code.present?

    reference = "pay_#{SecureRandom.hex(12)}"

    data = PaystackService.initialize_transaction(
      email: user.email,
      amount: amount_cents,
      reference: reference,
      callback_url: callback_url,
      currency: currency,
      metadata: {
        user_id: user.id,
        credits_purchased: credits,
        description: description
      }
    )

    payment = Payment.create!(
      user: user,
      paystack_reference: reference,
      client_secret: data["access_code"],
      amount_cents: amount_cents,
      currency: currency,
      status: "pending",
      description: description,
      credits_purchased: credits
    )

    { payment: payment, authorization_url: data["authorization_url"] }
  end
end
