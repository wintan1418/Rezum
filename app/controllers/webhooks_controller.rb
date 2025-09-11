class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_stripe_signature
  
  def stripe
    case @event.type
    when 'customer.subscription.created', 'customer.subscription.updated'
      handle_subscription_update(@event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(@event.data.object)
    when 'payment_intent.succeeded'
      handle_payment_succeeded(@event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failed(@event.data.object)
    when 'invoice.payment_succeeded'
      handle_invoice_payment_succeeded(@event.data.object)
    else
      Rails.logger.info "Unhandled Stripe event: #{@event.type}"
    end
    
    head :ok
  end
  
  private
  
  def verify_stripe_signature
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.config.stripe.webhook_secret
    
    begin
      @event = StripeService.construct_webhook_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON: #{e}"
      head :bad_request
      return
    rescue => e
      Rails.logger.error "Invalid signature: #{e}"
      head :bad_request
      return
    end
  end
  
  def handle_subscription_update(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
    return unless subscription
    
    subscription.update!(
      status: stripe_subscription.status,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      cancel_at_period_end: stripe_subscription.cancel_at_period_end,
      trial_start: stripe_subscription.trial_start ? Time.at(stripe_subscription.trial_start) : nil,
      trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
    )
  end
  
  def handle_subscription_deleted(stripe_subscription)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
    return unless subscription
    
    subscription.update!(status: 'canceled')
  end
  
  def handle_payment_succeeded(payment_intent)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment
    
    payment.sync_from_stripe!
  end
  
  def handle_payment_failed(payment_intent)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment
    
    payment.update!(status: 'canceled')
  end
  
  def handle_invoice_payment_succeeded(invoice)
    subscription_id = invoice.subscription
    return unless subscription_id
    
    subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
    return unless subscription
    
    # Update subscription status to active if payment succeeded
    subscription.update!(status: 'active') if subscription.status != 'active'
  end
end
