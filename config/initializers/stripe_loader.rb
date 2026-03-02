# Paystack configuration (replaces Stripe)
Rails.application.configure do
  config.paystack = ActiveSupport::OrderedOptions.new
  config.paystack.secret_key = Rails.application.credentials.dig(:paystack, :secret_key) || ENV["PAYSTACK_SECRET_KEY"]
  config.paystack.public_key = Rails.application.credentials.dig(:paystack, :public_key) || ENV["PAYSTACK_PUBLIC_KEY"]
end
