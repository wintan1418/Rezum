# Stripe configuration
Rails.application.configure do
  config.stripe = ActiveSupport::OrderedOptions.new
  config.stripe.publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key) || ENV['STRIPE_PUBLISHABLE_KEY']
  config.stripe.secret_key = Rails.application.credentials.dig(:stripe, :secret_key) || ENV['STRIPE_SECRET_KEY']
  config.stripe.webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret) || ENV['STRIPE_WEBHOOK_SECRET']
end

# Configure Stripe
Stripe.api_key = Rails.application.config.stripe.secret_key