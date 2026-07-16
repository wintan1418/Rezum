# Error monitoring — active only when SENTRY_DSN is set (production on
# Hatchbox). Without a DSN this initializer is a no-op, so development and
# test are unaffected.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Keep PII (emails, IPs, request bodies) out of error reports
    config.send_default_pii = false

    # Light performance tracing; raise if you want more visibility
    config.traces_sample_rate = 0.1

    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["HATCHBOX_RELEASE"].presence
  end
end
