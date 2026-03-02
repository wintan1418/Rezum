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
      provider: provider
    )

    parse_response(response)
  end

  private

  def system_prompt
    <<~PROMPT
      You are an expert LinkedIn profile optimizer and personal branding consultant.
      Optimize the user's LinkedIn profile sections to maximize visibility, engagement, and recruiter interest.

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

      Guidelines:
      - Use industry keywords naturally for SEO
      - Include quantifiable achievements where possible
      - Keep the tone professional but personable
      - Optimize for ATS and recruiter searches
      - Make the About section tell a compelling career story
      - Return ONLY valid JSON, no markdown or extra text.
    PROMPT
  end

  def user_prompt
    parts = ["Target Role: #{target_role}"]
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
end
