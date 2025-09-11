class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription, only: [:show, :cancel, :reactivate, :destroy]
  
  def new
    @subscription = current_user.subscriptions.build
    @plans = [
      {
        id: 'price_1QExampleMonthly',  # Replace with your actual Stripe Price ID
        name: 'Monthly Pro',
        price: 29,
        interval: 'month',
        features: ['Unlimited resumes', 'Unlimited cover letters', 'ATS optimization', 'Priority support']
      },
      {
        id: 'price_1QExampleAnnual',   # Replace with your actual Stripe Price ID
        name: 'Annual Pro',
        price: 290,
        interval: 'year',
        features: ['Unlimited resumes', 'Unlimited cover letters', 'ATS optimization', 'Priority support', '2 months free']
      }
    ]
  end
  
  def create
    plan_id = params[:plan_id]
    return redirect_to new_subscription_path, alert: 'Please select a plan' unless plan_id
    
    begin
      # Ensure user has a Stripe customer
      current_user.create_stripe_customer! unless current_user.stripe_customer_id
      
      # Create Stripe subscription
      stripe_subscription = StripeService.create_subscription(
        customer: current_user.stripe_customer_id,
        items: [{ price: plan_id }],
        payment_behavior: 'default_incomplete',
        payment_settings: { save_default_payment_method: 'on_subscription' },
        expand: ['latest_invoice.payment_intent']
      )
      
      # Create local subscription record
      subscription = current_user.subscriptions.create!(
        stripe_subscription_id: stripe_subscription.id,
        status: stripe_subscription.status,
        plan_id: plan_id,
        current_period_start: Time.at(stripe_subscription.current_period_start),
        current_period_end: Time.at(stripe_subscription.current_period_end),
        trial_start: stripe_subscription.trial_start ? Time.at(stripe_subscription.trial_start) : nil,
        trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
      )
      
      # Handle payment intent for confirmation
      payment_intent = stripe_subscription.latest_invoice.payment_intent
      
      if payment_intent.status == 'requires_action'
        # Client needs to confirm payment
        redirect_to subscription_path(subscription, client_secret: payment_intent.client_secret)
      else
        redirect_to subscription_path(subscription), notice: 'Subscription created successfully!'
      end
      
    rescue => e
      Rails.logger.error "Subscription creation failed: #{e.message}"
      redirect_to new_subscription_path, alert: "Subscription failed: #{e.message}"
    end
  end
  
  def show
    @payment_intent_client_secret = params[:client_secret]
  end
  
  def cancel
    begin
      @subscription.cancel_at_period_end!
      redirect_to subscription_path(@subscription), notice: 'Subscription will be canceled at the end of the current period.'
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to cancel subscription: #{e.message}"
    end
  end
  
  def reactivate
    begin
      @subscription.reactivate!
      redirect_to subscription_path(@subscription), notice: 'Subscription reactivated successfully!'
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to reactivate subscription: #{e.message}"
    end
  end
  
  def destroy
    begin
      # Immediately cancel the subscription
      StripeService.delete_subscription(@subscription.stripe_subscription_id)
      @subscription.update!(status: 'canceled')
      
      redirect_to billing_index_path, notice: 'Subscription canceled immediately.'
    rescue => e
      redirect_to subscription_path(@subscription), alert: "Failed to cancel subscription: #{e.message}"
    end
  end
  
  private
  
  def set_subscription
    @subscription = current_user.subscriptions.find(params[:id])
  end
end
