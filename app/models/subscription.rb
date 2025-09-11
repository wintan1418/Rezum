class Subscription < ApplicationRecord
  belongs_to :user
  
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active trialing past_due canceled unpaid incomplete incomplete_expired] }
  validates :plan_id, presence: true
  
  enum status: {
    active: 'active',
    trialing: 'trialing',
    past_due: 'past_due',
    canceled: 'canceled',
    unpaid: 'unpaid',
    incomplete: 'incomplete',
    incomplete_expired: 'incomplete_expired'
  }
  
  scope :active_subscriptions, -> { where(status: ['active', 'trialing']) }
  scope :canceled_subscriptions, -> { where(status: 'canceled') }
  
  def active?
    status.in?(['active', 'trialing']) && current_period_end&.future?
  end
  
  def trialing?
    status == 'trialing' && trial_end&.future?
  end
  
  def expired?
    current_period_end&.past?
  end
  
  def days_until_renewal
    return 0 unless current_period_end
    [(current_period_end.to_date - Date.current).to_i, 0].max
  end
  
  def plan_name
    case plan_id
    when 'price_monthly_pro'
      'Monthly Pro'
    when 'price_annual_pro'
      'Annual Pro'
    else
      plan_id&.humanize || 'Unknown Plan'
    end
  end
  
  def plan_price
    case plan_id
    when 'price_monthly_pro'
      29
    when 'price_annual_pro'
      290
    else
      0
    end
  end
  
  def billing_cycle
    case plan_id
    when 'price_monthly_pro'
      'monthly'
    when 'price_annual_pro'
      'annual'
    else
      'unknown'
    end
  end
  
  # Sync subscription data from Stripe
  def sync_from_stripe!
    return unless stripe_subscription_id
    
    stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
    
    update!(
      status: stripe_subscription.status,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      trial_start: stripe_subscription.trial_start ? Time.at(stripe_subscription.trial_start) : nil,
      trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
    )
  end
  
  # Cancel subscription at period end
  def cancel_at_period_end!
    return unless stripe_subscription_id
    
    Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: true }
    )
    
    update!(cancel_at_period_end: true)
  end
  
  # Reactivate canceled subscription
  def reactivate!
    return unless stripe_subscription_id && cancel_at_period_end?
    
    Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: false }
    )
    
    update!(cancel_at_period_end: false)
  end
end