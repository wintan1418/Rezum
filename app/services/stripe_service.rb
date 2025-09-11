class StripeService
  class << self
    def create_customer(email:, name:, metadata: {})
      Rails.logger.info "Creating Stripe customer for: #{email}"
      
      Stripe::Customer.create(
        email: email,
        name: name,
        metadata: metadata
      )
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe customer creation failed: #{e.message}"
      raise e
    end
    
    def retrieve_customer(customer_id)
      Rails.logger.info "Retrieving Stripe customer: #{customer_id}"
      
      Stripe::Customer.retrieve(customer_id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe customer retrieval failed: #{e.message}"
      raise e
    end
    
    def create_payment_intent(amount:, currency:, customer:, description:, metadata: {})
      Rails.logger.info "Creating Stripe payment intent for $#{amount/100.0}"
      
      Stripe::PaymentIntent.create(
        amount: amount,
        currency: currency,
        customer: customer,
        description: description,
        metadata: metadata,
        automatic_payment_methods: {
          enabled: true
        }
      )
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe payment intent creation failed: #{e.message}"
      raise e
    end
    
    def retrieve_payment_intent(payment_intent_id)
      Rails.logger.info "Retrieving Stripe payment intent: #{payment_intent_id}"
      
      Stripe::PaymentIntent.retrieve(payment_intent_id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe payment intent retrieval failed: #{e.message}"
      raise e
    end
    
    def create_subscription(customer:, items:, **options)
      Rails.logger.info "Creating Stripe subscription for customer: #{customer}"
      
      subscription_params = {
        customer: customer,
        items: items,
        payment_behavior: 'default_incomplete',
        payment_settings: { save_default_payment_method: 'on_subscription' },
        expand: ['latest_invoice.payment_intent']
      }.merge(options)
      
      Stripe::Subscription.create(subscription_params)
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe subscription creation failed: #{e.message}"
      raise e
    end
    
    def update_subscription(subscription_id, **params)
      Rails.logger.info "Updating Stripe subscription: #{subscription_id}"
      
      Stripe::Subscription.update(subscription_id, params)
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe subscription update failed: #{e.message}"
      raise e
    end
    
    def delete_subscription(subscription_id)
      Rails.logger.info "Deleting Stripe subscription: #{subscription_id}"
      
      Stripe::Subscription.delete(subscription_id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe subscription deletion failed: #{e.message}"
      raise e
    end
    
    def construct_webhook_event(payload, sig_header, endpoint_secret)
      Rails.logger.info "Constructing Stripe webhook event"
      
      Stripe::Webhook.construct_event(
        payload,
        sig_header,
        endpoint_secret
      )
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in webhook payload: #{e.message}"
      raise e
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Invalid webhook signature: #{e.message}"
      raise e
    end
    
    # Helper method to check if we're in test mode
    def test_mode?
      Rails.env.test? || Rails.env.development?
    end
    
    # Helper method to get the appropriate API key
    def api_key
      Rails.application.config.stripe.secret_key
    end
  end
end
