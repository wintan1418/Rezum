class AiService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Available AI Models
  GPT_4_MODEL = ENV.fetch("OPENAI_PRIMARY_MODEL", "gpt-4.1").freeze
  GPT_4_MINI_MODEL = ENV.fetch("OPENAI_FAST_MODEL", "gpt-4.1-mini").freeze
  CLAUDE_SONNET = ENV.fetch("ANTHROPIC_PRIMARY_MODEL", "claude-3-5-sonnet-latest").freeze
  GEMINI_PRO = ENV.fetch("GOOGLE_PRIMARY_MODEL", "gemini-2.0-flash").freeze

  attribute :user_id, :integer
  attribute :user_country, :string
  attribute :content, :string
  attribute :provider, :string, default: "openai"

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

  # Shared prompt block ensuring generated content matches the language of the
  # user's source material instead of defaulting to English.
  def language_preservation_rule(source: "the candidate's original resume")
    <<~PROMPT
      ## OUTPUT LANGUAGE (CRITICAL — overrides any other wording or header rules)
      - Detect the language of #{source} and write ALL generated content in that SAME language.
      - Produce English output ONLY when the source content is written in English. French input → French output, Spanish input → Spanish output, etc.
      - Use that language's standard professional section headers (e.g. French: "Profil Professionnel", "Compétences", "Expérience Professionnelle", "Formation", "Certifications").
      - Keep proper nouns, company names, and technical terms in their original form when they are conventionally not translated.
    PROMPT
  end

  def generate_completion(messages:, model: nil, max_tokens: 2000, temperature: 0.7, provider: nil, json: false)
    validate!

    # Use specified provider or fall back to instance provider
    current_provider = provider&.to_sym || self.provider.to_sym
    model ||= default_model_for_provider(current_provider)

    if @use_openai_gem || current_provider == :openai
      # Use OpenAI gem directly as fallback
      response = generate_with_openai_gem(messages, model, max_tokens, temperature, json: json)
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

  # Post-generation hallucination guard: returns claims in `generated` that
  # are not supported by `source`. Empty array means fully grounded.
  # Never raises — a guard failure must not break generation.
  def grounding_violations(source:, generated:)
    raw = generate_completion(
      messages: [
        { role: "system", content: <<~PROMPT },
          You are a strict fact-checker for career documents. Compare a GENERATED document against the SOURCE material it was derived from.

          Flag ONLY concrete claims in the GENERATED document that the SOURCE does not support:
          - Invented numbers: metrics, percentages, dollar amounts, team sizes, timeframes not present in or directly computable from the SOURCE
          - Skills, tools, technologies, or certifications never mentioned in the SOURCE
          - Job titles, companies, degrees, or institutions not in the SOURCE
          - Invented employer/company facts (mission, products, awards, news)

          Do NOT flag: rephrasing, synonyms, stronger verbs, reordering, qualitative scope language ("cross-functional", "high-volume"), or standard letter/resume conventions.

          Respond with JSON only: {"unsupported_claims": [{"claim": "<exact text from the generated document>", "reason": "<why it is unsupported>"}]}
          If everything is grounded, return {"unsupported_claims": []}.
        PROMPT
        { role: "user", content: "SOURCE:\n#{source}\n\nGENERATED DOCUMENT:\n#{generated}" }
      ],
      model: GPT_4_MINI_MODEL,
      max_tokens: 900,
      temperature: 0.0,
      provider: :openai,
      json: true
    )
    Array(JSON.parse(raw)["unsupported_claims"]).select { |c| c.is_a?(Hash) && c["claim"].present? }
  rescue StandardError => e
    Rails.logger.warn "Grounding check failed (skipping guard): #{e.message}"
    []
  end

  # Second half of the guard: rewrite `generated`, removing or softening only
  # the flagged claims. Returns the original text if the fix fails.
  def remove_unsupported_claims(generated:, violations:, style_note: nil)
    claims_list = violations.map { |v| "- \"#{v['claim']}\" (#{v['reason']})" }.join("\n")

    generate_completion(
      messages: [
        { role: "system", content: <<~PROMPT },
          You correct career documents that contain unsupported claims. Rewrite the document so every flagged claim is removed or softened to what the source material actually supports (e.g. drop an invented number but keep the achievement, remove a skill that was never mentioned).

          Rules:
          - Change ONLY the flagged claims. Preserve all other text exactly as written, including structure, order, and language.
          - Never introduce new facts, numbers, or skills.
          - Keep the document natural — no placeholder text, no commentary.
          #{style_note}
          - Output ONLY the corrected document. No explanations, no code fences.
        PROMPT
        { role: "user", content: "UNSUPPORTED CLAIMS TO FIX:\n#{claims_list}\n\nDOCUMENT:\n#{generated}" }
      ],
      model: GPT_4_MODEL,
      max_tokens: 4000,
      temperature: 0.2,
      provider: :openai
    )
  rescue StandardError => e
    Rails.logger.warn "Grounding fix failed (returning unfixed content): #{e.message}"
    generated
  end

  # Runs the full guard: verify, and revise once if violations are found.
  def with_grounding_guard(source:, generated:, style_note: nil)
    violations = grounding_violations(source: source, generated: generated)
    return generated if violations.empty?

    Rails.logger.info "Grounding guard: fixing #{violations.size} unsupported claim(s)"
    remove_unsupported_claims(generated: generated, violations: violations, style_note: style_note)
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
      CLAUDE_SONNET
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

  def generate_with_openai_gem(messages, model, max_tokens, temperature, json: false)
    client = OpenAI::Client.new

    parameters = {
      model: model || GPT_4_MINI_MODEL,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      user: user_id&.to_s
    }
    parameters[:response_format] = { type: "json_object" } if json

    client.chat(parameters: parameters)
  end

  def validate!
    raise StandardError.new(errors.full_messages.join(", ")) unless valid?
  end

  def validate_content?
    # Only validate content for base AiService, not for subclasses like CoverLetterGeneratorService
    self.class == AiService
  end
end
