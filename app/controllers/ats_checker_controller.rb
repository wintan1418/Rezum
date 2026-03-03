class AtsCheckerController < ApplicationController
  before_action :check_rate_limit, only: :check

  layout false

  def show
    @rate_limited = already_used_free_check? && !user_signed_in?
  end

  def check
    unless params[:resume_file].present?
      return render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: "Please upload a resume file." })
    end

    # Extract text from uploaded file
    processor = ResumeFileProcessorService.new(file: params[:resume_file])
    extraction = processor.process
    resume_text = extraction[:text]

    # Call AI for ATS scoring
    raw_response = score_with_ai(resume_text)

    # Parse structured response
    @results = AtsScoreParserService.new(raw_response).parse

    # Mark free check as used (for non-authenticated users)
    mark_free_check_used! unless user_signed_in?

    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/results", locals: { results: @results })
  rescue ResumeProcessingError => e
    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: e.message })
  rescue StandardError => e
    Rails.logger.error "ATS Checker error: #{e.message}"
    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: "Something went wrong analyzing your resume. Please try again." })
  end

  private

  def check_rate_limit
    return if user_signed_in?

    if already_used_free_check?
      render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/rate_limited")
    end
  end

  def already_used_free_check?
    Rails.cache.exist?("ats_free:#{request.remote_ip}")
  end

  def mark_free_check_used!
    Rails.cache.write("ats_free:#{request.remote_ip}", true, expires_in: 30.days)
  end

  def score_with_ai(resume_text)
    client = OpenAI::Client.new

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "RESUME:\n#{resume_text}\n\nAnalyze this resume against ATS best practices and provide a detailed score." }
    ]

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: messages,
        max_tokens: 1200,
        temperature: 0.1
      }
    )

    response.dig("choices", 0, "message", "content")&.strip || raise(StandardError, "Empty AI response")
  end

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
