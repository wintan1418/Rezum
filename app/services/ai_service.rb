class AiService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Available AI Models
  GPT_4_MODEL = 'gpt-4o'.freeze
  GPT_4_MINI_MODEL = 'gpt-4o-mini'.freeze
  CLAUDE_3_5_SONNET = 'claude-3-5-sonnet-20241022'.freeze
  GEMINI_PRO = 'gemini-1.5-pro'.freeze
  
  attribute :user_id, :integer
  attribute :user_country, :string
  attribute :content, :string
  attribute :provider, :string, default: 'openai'
  
  validates :content, presence: true, length: { minimum: 10 }, if: :validate_content?
  validates :provider, inclusion: { in: %w[openai anthropic google] }
  
  def initialize(attributes = {})
    super
    # Initialize RubyLLM client with fallback to OpenAI gem if needed
    begin
      @llm = RubyLLM::Client.new(provider: provider.to_sym)
    rescue => e
      Rails.logger.warn "RubyLLM initialization failed: #{e.message}, falling back to OpenAI gem"
      @use_openai_gem = true
    end
  end
  
  protected
  
  attr_reader :llm
  
  def generate_completion(messages:, model: nil, max_tokens: 2000, temperature: 0.7, provider: nil)
    validate!
    
    # Use specified provider or fall back to instance provider
    current_provider = provider&.to_sym || self.provider.to_sym
    model ||= default_model_for_provider(current_provider)
    
    if @use_openai_gem || current_provider == :openai
      # Use OpenAI gem directly as fallback
      response = generate_with_openai_gem(messages, model, max_tokens, temperature)
    else
      # Use RubyLLM
      response = llm.complete(
        messages: messages,
        model: model,
        max_tokens: max_tokens,
        temperature: temperature,
        user: user_id&.to_s,
        provider: current_provider
      )
    end
    
    handle_response(response, current_provider)
  rescue RubyLLM::Error => e
    Rails.logger.error "RubyLLM API Error: #{e.message}"
    raise StandardError.new("AI service temporarily unavailable. Please try again later.")
  rescue StandardError => e
    Rails.logger.error "AI Service Error: #{e.message}"
    raise StandardError.new("Something went wrong. Please try again.")
  end
  
  # Allow switching providers for different use cases
  def with_provider(provider_name)
    self.provider = provider_name.to_s
    @llm = RubyLLM::Client.new(provider: provider_name.to_sym)
    self
  end
  
  private
  
  def default_model_for_provider(provider)
    case provider
    when :openai
      GPT_4_MINI_MODEL
    when :anthropic
      CLAUDE_3_5_SONNET
    when :google
      GEMINI_PRO
    else
      GPT_4_MINI_MODEL
    end
  end
  
  def handle_response(response, provider)
    content = case provider
              when :openai
                response.dig("choices", 0, "message", "content")
              when :anthropic
                response.dig("content", 0, "text")
              when :google
                response.dig("candidates", 0, "content", "parts", 0, "text")
              else
                response.dig("choices", 0, "message", "content")
              end
    
    if content&.strip&.present?
      content.strip
    else
      raise StandardError.new("Invalid response from AI service")
    end
  end
  
  def generate_with_openai_gem(messages, model, max_tokens, temperature)
    client = OpenAI::Client.new
    
    response = client.chat(
      parameters: {
        model: model || GPT_4_MINI_MODEL,
        messages: messages,
        max_tokens: max_tokens,
        temperature: temperature,
        user: user_id&.to_s
      }
    )
    
    response
  end
  
  def validate!
    raise StandardError.new(errors.full_messages.join(", ")) unless valid?
  end

  def validate_content?
    # Only validate content for base AiService, not for subclasses like CoverLetterGeneratorService
    self.class == AiService
  end
end