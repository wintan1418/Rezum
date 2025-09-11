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
    Rails.logger.info "Purchase credits called with params: #{params.inspect}"
    credits = params[:credits].to_i
    Rails.logger.info "Credits parsed: #{credits}"
    
    if credits <= 0
      Rails.logger.info "Invalid credits amount, redirecting"
      return redirect_to billing_index_path, alert: 'Invalid credit amount'
    end
    
    # Pricing: $5 for 10 credits, $15 for 35 credits, $30 for 75 credits
    amount_cents = case credits
                   when 10
                     500  # $5
                   when 35
                     1500 # $15
                   when 75
                     3000 # $30
                   else
                     credits * 50 # $0.50 per credit as fallback
                   end
    
    Rails.logger.info "Creating payment with amount_cents: #{amount_cents}"
    
    begin
      payment = Payment.create_stripe_payment_intent(
        user: current_user,
        amount_cents: amount_cents,
        currency: current_user.preferred_currency.downcase,
        description: "#{credits} Credits Purchase",
        credits: credits
      )
      
      Rails.logger.info "Payment created successfully: #{payment.id}"
      redirect_to billing_path(payment), notice: 'Payment initiated successfully!'
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      user_friendly_message = case e.message
                             when /No such customer/
                               "Customer account issue. Please try again."
                             when /Invalid API Key/
                               "Payment system configuration error. Please contact support."
                             when /No such price/
                               "Selected plan is not available. Please try a different option."
                             else
                               "Payment failed: #{e.message}"
                             end
      redirect_to billing_index_path, alert: user_friendly_message
    rescue => e
      Rails.logger.error "Payment failed: #{e.class}: #{e.message}"
      redirect_to billing_index_path, alert: "Payment failed: Please try again later"
    end
  end
  
  def show
    @payment = current_user.payments.find(params[:id])
    
    # Handle successful payment redirect from Stripe
    if params[:redirect_status] == 'succeeded' && params[:payment_intent]
      Rails.logger.info "Payment succeeded, syncing status for payment: #{@payment.id}"
      @payment.sync_from_stripe!
      
      # Add credits if this was a credit purchase
      if @payment.succeeded? && @payment.credits_purchased.present?
        current_user.add_credits(@payment.credits_purchased)
        flash[:notice] = "Payment successful! #{@payment.credits_purchased} credits have been added to your account."
      end
    end
  end
end
