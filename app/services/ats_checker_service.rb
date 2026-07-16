# Free public ATS check: scores a resume against general ATS best practices
# (no job description). Runs inside AtsCheckerJob so the lead-magnet page
# never blocks a web thread on an AI call.
class AtsCheckerService
  def score(resume_text)
    client = OpenAI::Client.new

    response = client.chat(
      parameters: {
        model: AiService::GPT_4_MINI_MODEL,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "RESUME:\n#{resume_text}\n\nAnalyze this resume against ATS best practices and provide a detailed score." }
        ],
        max_tokens: 1200,
        temperature: 0.1
      }
    )

    response.dig("choices", 0, "message", "content")&.strip || raise(StandardError, "Empty AI response")
  end

  private

  def system_prompt
    <<~PROMPT
      You are an ATS (Applicant Tracking System) scoring expert. You analyze resumes against general ATS best practices — no job description is needed.

      Score the resume on these criteria:

      **FORMAT (40% of score):**
      - Standard section headers (Summary, Experience, Education, Skills)
      - Consistent date formatting
      - No tables, columns, headers/footers, or graphics that break ATS parsing
      - Contact information present and complete (name, email, phone, location)
      - Appropriate length (1-2 pages worth of content)
      - Clean text without special characters or unicode issues

      **CONTENT (60% of score):**
      - Professional summary present and compelling
      - Experience bullets start with strong action verbs (not "Responsible for", "Helped with")
      - Quantified achievements with metrics (numbers, percentages, dollar amounts)
      - Skills section with relevant technical and domain keywords
      - Education section with degree details
      - Consistent verb tense (past for previous roles, present for current)
      - No personal pronouns (I, me, my)
      - No spelling or grammar red flags

      LANGUAGE: Write the strengths, issues, and improvements in the same language as the resume, so the candidate can read them. The format labels below (OVERALL ATS SCORE, FORMAT SCORE, CONTENT SCORE, STRENGTHS, ISSUES, IMPROVEMENTS) must stay EXACTLY in English — they are machine-parsed.

      Respond in EXACTLY this format:

      OVERALL ATS SCORE: [0-100]
      FORMAT SCORE: [0-100]
      CONTENT SCORE: [0-100]
      STRENGTHS: [comma-separated list of 3-5 things the resume does well]
      ISSUES: [comma-separated list of 3-5 problems found]
      IMPROVEMENTS:
      1. [specific actionable improvement]
      2. [specific actionable improvement]
      3. [specific actionable improvement]
      4. [specific actionable improvement]
      5. [specific actionable improvement]

      Be honest and precise. If the resume is weak, say so. Scores below 50 are poor, 50-74 need work, 75+ is good.
    PROMPT
  end
end
