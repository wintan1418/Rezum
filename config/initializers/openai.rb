# OpenAI Configuration
OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
  config.organization_id = Rails.application.credentials.openai_organization_id || ENV['OPENAI_ORGANIZATION_ID'] # Optional
  config.log_errors = Rails.env.development? # Only log API errors in development
end

# RubyLLM Configuration for multiple AI providers
RubyLLM.configure do |config|
  # OpenAI
  config.openai_api_key = Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
  
  # Anthropic Claude (optional)
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key || ENV['ANTHROPIC_API_KEY']
  
  # Google Gemini (optional) - may not be available in all versions
  # config.google_api_key = Rails.application.credentials.google_api_key || ENV['GOOGLE_API_KEY']
end