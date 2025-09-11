class Payment < ApplicationRecord
  
  belongs_to :user
  
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: %w[requires_payment_method requires_confirmation requires_action processing requires_capture canceled succeeded] }
  validates :credits_purchased, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  monetize :amount_cents
  
  enum status: {
    requires_payment_method: 'requires_payment_method',
    requires_confirmation: 'requires_confirmation', 
    requires_action: 'requires_action',
    processing: 'processing',
    requires_capture: 'requires_capture',
    canceled: 'canceled',
    succeeded: 'succeeded'
  }
  
  scope :successful, -> { where(status: 'succeeded') }
  scope :recent, -> { order(created_at: :desc) }
  scope :credit_purchases, -> { where.not(credits_purchased: nil) }
  
  def successful?
    status == 'succeeded'
  end
  
  def failed?
    status.in?(['canceled'])
  end
  
  def pending?
    status.in?(['requires_payment_method', 'requires_confirmation', 'requires_action', 'processing', 'requires_capture'])
  end
  
  def amount_display
    "#{amount.format(symbol: currency_symbol)}"
  end
  
  def currency_symbol
    case currency.upcase
    when 'USD'
      '$'
    when 'EUR'
      '€'
    when 'GBP'
      '£'
    else
      currency.upcase
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
  
  # Sync payment data from Stripe
  def sync_from_stripe!
    return unless stripe_payment_intent_id
    
    payment_intent = StripeService.retrieve_payment_intent(stripe_payment_intent_id)
    
    update!(
      status: payment_intent.status,
      amount_cents: payment_intent.amount,
      currency: payment_intent.currency
    )
    
    # If payment succeeded and credits were purchased, add them to user
    if succeeded? && credits_purchased.present?
      user.add_credits(credits_purchased)
    end
  end
  
  # Create Stripe PaymentIntent
  def self.create_stripe_payment_intent(user:, amount_cents:, currency: 'usd', description: nil, credits: nil)
    # Ensure user has a Stripe customer
    user.create_stripe_customer! unless user.stripe_customer_id
    
    payment_intent = StripeService.create_payment_intent(
      amount: amount_cents,
      currency: currency,
      customer: user.stripe_customer_id,
      description: description,
      metadata: {
        user_id: user.id,
        credits_purchased: credits
      }
    )
    
    payment = Payment.create!(
      user: user,
      stripe_payment_intent_id: payment_intent.id,
      client_secret: payment_intent.client_secret,
      amount_cents: amount_cents,
      currency: currency,
      status: payment_intent.status,
      description: description,
      credits_purchased: credits
    )
    
    # Credits will be added when webhook confirms payment success
    payment
  end
end
