class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_paystack_signature

  def paystack
    event = @event['event']
    data = @event['data']

    case event
    when 'charge.success'
      handle_charge_success(data)
    when 'subscription.create'
      handle_subscription_create(data)
    when 'subscription.not_renew'
      handle_subscription_not_renew(data)
    when 'subscription.disable'
      handle_subscription_disable(data)
    when 'invoice.create', 'invoice.update'
      handle_invoice(data)
    when 'transfer.success', 'transfer.failed'
      Rails.logger.info "Paystack transfer event: #{event}"
    else
      Rails.logger.info "Unhandled Paystack event: #{event}"
    end

    head :ok
  end

  private

  def verify_paystack_signature
    payload = request.body.read
    signature = request.headers['X-Paystack-Signature']

    unless PaystackService.verify_webhook(payload, signature)
      Rails.logger.error "Invalid Paystack webhook signature"
      head :bad_request
      return
    end

    @event = JSON.parse(payload)
  rescue JSON::ParserError => e
    Rails.logger.error "Invalid JSON in Paystack webhook: #{e.message}"
    head :bad_request
  end

  def handle_charge_success(data)
    reference = data['reference']
    return unless reference

    payment = Payment.find_by(paystack_reference: reference)
    return unless payment

    payment.update!(status: 'success')

    if payment.credits_purchased.present?
      payment.user.add_credits(payment.credits_purchased)
    end
  end

  def handle_subscription_create(data)
    subscription_code = data['subscription_code']
    customer_code = data.dig('customer', 'customer_code')
    return unless subscription_code && customer_code

    user = User.find_by(paystack_customer_code: customer_code)
    return unless user

    plan_code = data.dig('plan', 'plan_code')
    plan_id = Subscription::PLAN_CODES.key(plan_code) || plan_code

    subscription = user.subscriptions.find_or_initialize_by(paystack_subscription_code: subscription_code)
    subscription.assign_attributes(
      status: 'active',
      plan_id: plan_id,
      current_period_start: data['createdAt'] ? Time.parse(data['createdAt']) : Time.current,
      current_period_end: data['next_payment_date'] ? Time.parse(data['next_payment_date']) : 1.month.from_now
    )
    subscription.save!
  end

  def handle_subscription_not_renew(data)
    subscription_code = data['subscription_code']
    return unless subscription_code

    subscription = Subscription.find_by(paystack_subscription_code: subscription_code)
    return unless subscription

    subscription.update!(cancel_at_period_end: true)
  end

  def handle_subscription_disable(data)
    subscription_code = data['subscription_code']
    return unless subscription_code

    subscription = Subscription.find_by(paystack_subscription_code: subscription_code)
    return unless subscription

    subscription.update!(status: 'canceled')
  end

  def handle_invoice(data)
    subscription_code = data.dig('subscription', 'subscription_code')
    return unless subscription_code

    subscription = Subscription.find_by(paystack_subscription_code: subscription_code)
    return unless subscription

    if data['paid']
      subscription.update!(status: 'active')
    end
  end
end
