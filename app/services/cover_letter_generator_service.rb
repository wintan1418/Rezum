class CoverLetterGeneratorService < AiService
  attribute :resume_content, :string
  attribute :job_description, :string
  attribute :company_name, :string
  attribute :hiring_manager_name, :string
  attribute :target_role, :string
  attribute :tone, :string, default: "professional"
  attribute :length, :string, default: "medium"

  validates :resume_content, presence: true, length: { minimum: 100 }
  validates :job_description, length: { minimum: 50 }, allow_blank: true
  validates :company_name, presence: true, length: { minimum: 2 }
  validates :target_role, presence: true, length: { minimum: 2 }
  validates :tone, inclusion: { in: %w[professional friendly confident casual enthusiastic] }
  validates :length, inclusion: { in: %w[short medium long] }

  # ISO 639-1 code of the language the AI reports writing the letter in.
  # Populated by sanitize_body_only; defaults to "en".
  attr_reader :detected_language

  def generate
    messages = build_generation_messages

    selected_provider = preferred_provider
    model = model_for_provider(selected_provider)

    content = generate_completion(
      messages: messages,
      model: model,
      max_tokens: token_limit_for_length,
      temperature: temperature_for_tone,
      provider: selected_provider
    )
    sanitize_body_only(content)
  end

  def generate_variations(count: 3)
    variations = []

    count.times do |i|
      current_provider = preferred_provider

      messages = build_variation_messages(i + 1)

      variation = with_provider(current_provider).generate_completion(
        messages: messages,
        model: model_for_provider(current_provider),
        max_tokens: token_limit_for_length,
        temperature: temperature_for_tone + (i * 0.1) # Slight temperature variation
      )

      variations << {
        version: i + 1,
        content: sanitize_body_only(variation),
        language: detected_language,
        provider: current_provider,
        tone: tone,
        length: length
      }
    end

    variations
  end

  def personalize_for_company
    messages = build_personalization_messages

    generate_completion(
      messages: messages,
      model: GPT_4_MODEL,
      max_tokens: token_limit_for_length,
      temperature: 0.4
    )
  end

  private

  def build_generation_messages
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt

    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]
  end

  def build_system_prompt
    regional_context = user_country == "US" ? "American" : (user_country&.in?([ "UK", "GB" ]) ? "British" : "International")

    <<~PROMPT
      You are an expert cover letter writer and career consultant with 15+ years of experience helping professionals secure interviews and job offers.

      #{language_preservation_rule(source: "the candidate's resume and the job posting")}
      - When the resume and job posting are in different languages, follow the language of the job posting (the letter addresses that employer).

      Your expertise includes:
      - #{regional_context} business communication standards
      - Industry-specific language and terminology
      - Compelling storytelling and achievement highlighting
      - ATS-friendly formatting and keyword optimization
      - Psychology of hiring managers and recruiters
      - Modern professional communication trends

      CRITICAL REQUIREMENTS:
      1. Write in a #{tone} tone that feels authentic and engaging
      2. Create a #{length} length cover letter (#{word_count_for_length} words)
      3. Match the candidate's authentic voice and experience from their resume
      4. Incorporate specific details from the job description naturally when one is provided
      5. Highlight 2-3 most relevant achievements with quantified impact
      6. Include a compelling opening that grabs attention
      7. End with a confident call-to-action
      8. Ensure ATS compatibility with relevant keywords
      9. Follow #{regional_context} business letter conventions
      10. Never fabricate experience or skills not in the original resume
      11. Use only company facts present in the job posting or resume. Do not invent company mission, products, news, culture, awards, or values.

      OUTPUT CONTRACT:
      - The FIRST line of your response must be exactly "LANGUAGE: <code>" where <code> is the two-letter ISO 639-1 code of the language you wrote the letter in (e.g. "LANGUAGE: fr"). Then a blank line, then the letter body.
      - After that line, return ONLY the body paragraphs of the cover letter.
      - Do NOT include sender contact details, date, recipient address, subject/Re line, greeting, "Dear...", sign-off, "Sincerely", or the candidate's name.
      - Do NOT wrap the output in markdown or code fences.
      - Paragraphs only; no bullet lists unless the job posting explicitly asks for a bullet-style response.
    PROMPT
  end

  def build_user_prompt
    hiring_manager_greeting = hiring_manager_name.present? ?
      "Dear #{hiring_manager_name}," :
      "Dear Hiring Manager,"

    <<~PROMPT
      CANDIDATE'S RESUME:
      #{resume_content}

      #{job_description_section}

      POSITION: #{target_role} at #{company_name}
      GREETING CONTEXT: #{hiring_manager_greeting}
      TONE: #{tone.capitalize}
      LENGTH: #{length.capitalize} (#{word_count_for_length} words)

      Create a compelling cover letter that:
      1. Opens with a strong, attention-grabbing first paragraph
      2. Demonstrates clear understanding of the role#{job_description.present? ? " and the provided job posting" : " using only the resume, target role, and company name provided"}
      3. Highlights the candidate's most relevant experience and achievements
      4. Shows genuine enthusiasm without inventing company-specific facts
      5. Includes specific examples with quantified results where possible
      6. Addresses key requirements from the job posting when provided
      7. Concludes with a confident call-to-action

      The cover letter should feel personal, authentic, and tailored specifically to this opportunity.
      Return body paragraphs only. The application will add the greeting, date, contact details, and signature.
    PROMPT
  end

  def build_variation_messages(version_number)
    system_prompt = build_system_prompt

    variation_instructions = case version_number
    when 1
      "Focus on achievements and quantifiable results. Use a confident, results-driven approach."
    when 2
      "Emphasize cultural fit and passion for the company/industry. Use a more personal, enthusiastic tone."
    when 3
      "Highlight problem-solving abilities and unique value proposition. Use a strategic, solution-oriented approach."
    else
      "Create a balanced approach combining achievements, passion, and strategic thinking."
    end

    user_prompt = "#{build_user_prompt}\n\nVARIATION #{version_number} APPROACH: #{variation_instructions}"

    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]
  end

  def build_personalization_messages
    [
      {
        role: "system",
        content: "You are a company research expert. Help personalize cover letters with specific, relevant details about companies and their culture."
      },
      {
        role: "user",
        content: <<~PROMPT
          Company: #{company_name}
          Position: #{target_role}

          Based on this job posting, suggest 2-3 specific details about #{company_name} that could be naturally incorporated into a cover letter to show research and genuine interest:

          #{job_description}

          Focus on:
          1. Company mission, values, or recent achievements
          2. Industry challenges they're addressing
          3. Growth opportunities or initiatives mentioned

          Provide specific, actionable suggestions for personalization.
        PROMPT
      }
    ]
  end

  def job_description_section
    if job_description.present?
      "JOB POSTING:\n#{job_description}"
    else
      "JOB POSTING: Not provided. Write a strong general cover letter for the target role without pretending to know specific job requirements."
    end
  end

  def preferred_provider
    provider.presence&.to_sym || :openai
  end

  def model_for_provider(provider_name)
    case provider_name.to_sym
    when :anthropic
      CLAUDE_SONNET
    when :google
      GEMINI_PRO
    else
      GPT_4_MODEL
    end
  end

  def sanitize_body_only(content)
    text = content.to_s
      .sub(/\A\s*```(?:text|markdown|plain)?\s*\n?/, "")
      .sub(/\n?\s*```\s*\z/, "")

    @detected_language = "en"
    text = text.sub(/\A\s*LANGUAGE:\s*([a-z]{2})\b[^\n]*\n?/i) do
      @detected_language = Regexp.last_match(1).downcase
      ""
    end

    lines = text.lines.map(&:rstrip)

    lines = lines.drop_while { |line| removable_letter_line?(line) || line.strip.blank? }
    if (closing_index = lines.rindex { |line| closing_line?(line) })
      lines = lines.first(closing_index)
    end
    lines = lines.reverse.drop_while { |line| removable_letter_line?(line) || line.strip.blank? }.reverse
    lines.join("\n").strip
  end

  def removable_letter_line?(line)
    text = line.to_s.strip
    return true if text.blank?
    return true if text.match?(/\A(dear\s+.+,|to\s+whom\s+it\s+may\s+concern,?)\z/i)
    return true if text.match?(/\A(madame,?\s*monsieur,?|madame\s+.+,|monsieur\s+.+,|bonjour,?|estimad[oa]s?\s+.+[,:]|sehr\s+geehrte.+,|gentile\s+.+,|prezad[oa]s?\s+.+[,:])\z/i)
    return true if closing_line?(text)
    return true if text.match?(/\A(re|subject):\s+/i)
    return true if text.match?(/\A#{Regexp.escape(company_name.to_s)}\z/i)
    return true if text.match?(/\A#{Regexp.escape(target_role.to_s)}\s+position\z/i)
    return true if parseable_date_line?(text)

    false
  end

  def parseable_date_line?(text)
    Date.parse(text)
    text.length <= 30
  rescue ArgumentError
    false
  end

  def closing_line?(line)
    text = line.to_s.strip
    return true if text.match?(/\A(sincerely|best regards|kind regards|regards|thank you),?\z/i)

    text.match?(/\A((bien\s+)?cordialement|salutations\s+distingu[ée]es|atentamente|un\s+saludo|saludos(\s+cordiales)?|atenciosamente|mit\s+freundlichen\s+gr[üu][ßs]en|cordiali\s+saluti|distinti\s+saluti),?\z/i)
  end

  def word_count_for_length
    case length
    when "short"
      "200-250"
    when "medium"
      "300-400"
    when "long"
      "450-600"
    else
      "300-400"
    end
  end

  def token_limit_for_length
    case length
    when "short"
      400
    when "medium"
      600
    when "long"
      900
    else
      600
    end
  end

  def temperature_for_tone
    case tone
    when "professional"
      0.3
    when "confident"
      0.4
    when "friendly"
      0.6
    when "enthusiastic"
      0.7
    when "casual"
      0.8
    else
      0.4
    end
  end
end
