require "net/http"
require "json"

class PaystackService
  BASE_URL = "https://api.paystack.co".freeze

  class PaystackError < StandardError; end

  class << self
    # ==================== TRANSACTIONS ====================

    def initialize_transaction(email:, amount:, reference: nil, callback_url: nil, metadata: {}, plan: nil)
      Rails.logger.info "Paystack: Initializing transaction for #{email}, amount: #{amount}"

      body = { email: email, amount: amount, metadata: metadata }
      body[:reference] = reference if reference
      body[:callback_url] = callback_url if callback_url
      body[:plan] = plan if plan

      response = post("/transaction/initialize", body)
      response["data"]
    end

    def verify_transaction(reference)
      Rails.logger.info "Paystack: Verifying transaction #{reference}"
      response = get("/transaction/verify/#{reference}")
      response["data"]
    end

    # ==================== CUSTOMERS ====================

    def create_customer(email:, first_name: nil, last_name: nil, metadata: {})
      Rails.logger.info "Paystack: Creating customer for #{email}"

      body = { email: email }
      body[:first_name] = first_name if first_name
      body[:last_name] = last_name if last_name
      body[:metadata] = metadata if metadata.present?

      response = post("/customer", body)
      response["data"]
    end

    def fetch_customer(email_or_code)
      Rails.logger.info "Paystack: Fetching customer #{email_or_code}"
      response = get("/customer/#{email_or_code}")
      response["data"]
    end

    # ==================== PLANS ====================

    def create_plan(name:, amount:, interval:, description: nil)
      Rails.logger.info "Paystack: Creating plan #{name}"

      body = { name: name, amount: amount, interval: interval }
      body[:description] = description if description

      response = post("/plan", body)
      response["data"]
    end

    def list_plans
      response = get("/plan")
      response["data"]
    end

    def fetch_plan(plan_id_or_code)
      response = get("/plan/#{plan_id_or_code}")
      response["data"]
    end

    # ==================== SUBSCRIPTIONS ====================

    def create_subscription(customer:, plan:, authorization: nil)
      Rails.logger.info "Paystack: Creating subscription for customer #{customer} on plan #{plan}"

      body = { customer: customer, plan: plan }
      body[:authorization] = authorization if authorization

      response = post("/subscription", body)
      response["data"]
    end

    def fetch_subscription(id_or_code)
      response = get("/subscription/#{id_or_code}")
      response["data"]
    end

    def enable_subscription(code:, token:)
      post("/subscription/enable", { code: code, token: token })
    end

    def disable_subscription(code:, token:)
      Rails.logger.info "Paystack: Disabling subscription #{code}"
      post("/subscription/disable", { code: code, token: token })
    end

    # ==================== WEBHOOK VERIFICATION ====================

    def verify_webhook(payload, signature)
      return false if secret_key.blank? || payload.blank? || signature.blank?

      computed = OpenSSL::HMAC.hexdigest("SHA512", secret_key, payload)
      ActiveSupport::SecurityUtils.secure_compare(computed, signature.to_s)
    end

    # ==================== HELPERS ====================

    def secret_key
      Rails.application.config.paystack.secret_key
    end

    def public_key
      Rails.application.config.paystack.public_key
    end

    def test_mode?
      secret_key&.start_with?("sk_test_")
    end

    private

    def get(path)
      uri = URI("#{BASE_URL}#{path}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{secret_key}"
      request["Content-Type"] = "application/json"

      execute(uri, request)
    end

    def post(path, body)
      uri = URI("#{BASE_URL}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{secret_key}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      execute(uri, request)
    end

    def execute(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      response = http.request(request)
      parsed = JSON.parse(response.body)

      unless parsed["status"]
        Rails.logger.error "Paystack API error: #{parsed['message']}"
        raise PaystackError, parsed["message"] || "Paystack API request failed"
      end

      parsed
    rescue JSON::ParserError => e
      Rails.logger.error "Paystack: Invalid JSON response: #{e.message}"
      raise PaystackError, "Invalid response from Paystack"
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "Paystack: Timeout: #{e.message}"
      raise PaystackError, "Payment service is temporarily unavailable"
    end
  end
end
