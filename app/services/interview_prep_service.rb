class InterviewPrepService < AiService
  attribute :job_description, :string
  attribute :company_name, :string
  attribute :target_role, :string
  attribute :resume_content, :string

  validates :target_role, presence: true

  def generate_questions
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

    parse_questions(response)
  end

  def generate_company_questions
    messages = [
      { role: "system", content: company_questions_system_prompt },
      { role: "user", content: company_questions_user_prompt }
    ]

    response = generate_completion(
      messages: messages,
      model: GPT_4_MINI_MODEL,
      max_tokens: 1500,
      temperature: 0.4,
      provider: provider
    )

    parse_company_questions(response)
  end

  private

  def system_prompt
    <<~PROMPT
      You are an expert interview coach with 20+ years of experience preparing candidates for job interviews.
      Generate likely interview questions with detailed STAR-method answer frameworks.

      Return your response as a JSON array of objects with this exact structure:
      [
        {
          "category": "behavioral|technical|situational|role_specific",
          "question": "The interview question",
          "why_asked": "Brief explanation of what the interviewer is evaluating",
          "answer_framework": "A structured answer framework using the STAR method (Situation, Task, Action, Result) that the candidate can personalize"
        }
      ]

      Generate 10-12 questions covering all categories. Tailor questions to the specific role and industry.
      Return ONLY valid JSON, no markdown or extra text.
    PROMPT
  end

  def user_prompt
    parts = ["Target Role: #{target_role}"]
    parts << "Company: #{company_name}" if company_name.present?
    parts << "\nJob Description:\n#{job_description}" if job_description.present?
    parts << "\nCandidate's Resume Summary:\n#{resume_content[0..2000]}" if resume_content.present?
    parts.join("\n")
  end

  def company_questions_system_prompt
    <<~PROMPT
      You are an expert career coach. Generate insightful questions that a candidate should ask the interviewer.
      These should demonstrate genuine interest, strategic thinking, and help the candidate evaluate the opportunity.

      Return your response as a JSON array of objects:
      [
        {
          "category": "culture|growth|role|team|strategy",
          "question": "The question to ask",
          "purpose": "Why this question is valuable to ask"
        }
      ]

      Generate 5-8 questions. Return ONLY valid JSON, no markdown or extra text.
    PROMPT
  end

  def company_questions_user_prompt
    parts = ["Target Role: #{target_role}"]
    parts << "Company: #{company_name}" if company_name.present?
    parts << "\nJob Description:\n#{job_description}" if job_description.present?
    parts.join("\n")
  end

  def parse_questions(response)
    JSON.parse(response)
  rescue JSON::ParserError
    # Try to extract JSON from markdown code blocks
    json_match = response.match(/\[[\s\S]*\]/)
    json_match ? JSON.parse(json_match[0]) : []
  end

  def parse_company_questions(response)
    JSON.parse(response)
  rescue JSON::ParserError
    json_match = response.match(/\[[\s\S]*\]/)
    json_match ? JSON.parse(json_match[0]) : []
  end
end
