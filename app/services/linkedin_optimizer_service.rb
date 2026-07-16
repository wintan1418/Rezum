class LinkedinOptimizerService < AiService
  attribute :current_headline, :string
  attribute :current_about, :string
  attribute :current_experience, :string
  attribute :target_role, :string
  attribute :resume_content, :string

  validates :target_role, presence: true

  def optimize
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]

    response = generate_completion(
      messages: messages,
      model: GPT_4_MODEL,
      max_tokens: 3000,
      temperature: 0.4,
      provider: :openai,
      json: true
    )

    apply_grounding_guard(parse_response(response))
  end

  private

  def system_prompt
    <<~PROMPT
      You are an expert LinkedIn profile optimizer and personal branding consultant.
      Optimize the user's LinkedIn profile sections to maximize visibility, engagement, and recruiter interest.

      #{language_preservation_rule(source: "the user's current profile sections and resume content")}
      - JSON keys and the "section"/"priority" enum values MUST remain in English exactly as specified below — only the human-readable content is written in the user's language.

      Return your response as a JSON object with this exact structure:
      {
        "headline_options": ["3-5 optimized headline variations"],
        "about": "Optimized About section (2-3 paragraphs, keyword-rich, engaging)",
        "experience": "Optimized experience bullets (improved impact statements with metrics)",
        "suggestions": [
          {
            "section": "headline|about|experience|skills|general",
            "suggestion": "Specific actionable improvement suggestion",
            "priority": "high|medium|low"
          }
        ]
      }

      LinkedIn-specific rules (these are hard platform constraints):
      - Every headline option: 220 characters MAX. Lead with the target role/value, not "Aspiring" or buzzwords. Use " | " separators sparingly.
      - About section: 2,600 characters max, BUT only the first ~3 lines show before "...see more" — the first sentence must hook (a concrete achievement, a sharp positioning statement, or a number). Write in FIRST person.
      - Recruiter search works on exact keywords: include the target role's standard title and its common variants naturally.

      Guidelines:
      - Use industry keywords naturally for SEO
      - Include quantifiable achievements ONLY when the user's material provides the numbers — never invent metrics
      - Keep the tone professional but personable
      - Make the About section tell a compelling career story
      - NEVER use AI-tell words: "delve," "pivotal," "passionate about," "results-driven," "proven track record," "dynamic," "synergy"
      - Return ONLY valid JSON, no markdown or extra text.
    PROMPT
  end

  def user_prompt
    parts = [ "Target Role: #{target_role}" ]
    parts << "\nCurrent Headline:\n#{current_headline}" if current_headline.present?
    parts << "\nCurrent About:\n#{current_about}" if current_about.present?
    parts << "\nCurrent Experience:\n#{current_experience}" if current_experience.present?
    parts << "\nResume Content:\n#{resume_content[0..2000]}" if resume_content.present?
    parts.join("\n")
  end

  def parse_response(response)
    JSON.parse(response)
  rescue JSON::ParserError
    json_match = response.match(/\{[\s\S]*\}/)
    json_match ? JSON.parse(json_match[0]) : {}
  end

  # Hallucination guard: the About and Experience rewrites may only claim
  # what the user's own material supports.
  def apply_grounding_guard(data)
    source = [
      ("RESUME:\n#{resume_content}" if resume_content.present?),
      ("CURRENT HEADLINE:\n#{current_headline}" if current_headline.present?),
      ("CURRENT ABOUT:\n#{current_about}" if current_about.present?),
      ("CURRENT EXPERIENCE:\n#{current_experience}" if current_experience.present?)
    ].compact.join("\n\n")
    return data if source.blank?

    %w[about experience].each do |field|
      next if data[field].blank?

      data[field] = with_grounding_guard(
        source: source,
        generated: data[field],
        style_note: "- This is a LinkedIn #{field} section: keep first person, structure, and language unchanged."
      )
    end

    data
  end
end
