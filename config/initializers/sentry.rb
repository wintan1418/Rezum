# Error monitoring. The DSN is Sentry's public client key (safe to commit);
# SENTRY_DSN in the environment overrides it. Test env stays silent.
Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", "https://4af2c4696c326aaf776d74c241eab032@o4511746074476544.ingest.us.sentry.io/4511746079129600")
  config.enabled_environments = %w[development production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Resumes and emails are sensitive — keep request bodies, user emails, and
  # IPs out of error reports
  config.send_default_pii = false

  # Forward Rails logs to Sentry's log stream
  config.enable_logs = true
  config.enabled_patches = [ :logger ]

  # Sample 10% of requests for tracing/profiling — raise if you want more
  # visibility, at the cost of overhead and quota
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1

  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
  config.release = ENV["HATCHBOX_RELEASE"].presence
end
