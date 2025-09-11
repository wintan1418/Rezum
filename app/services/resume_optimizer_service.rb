class ResumeOptimizerService < AiService
  attribute :job_description, :string
  attribute :target_role, :string
  attribute :industry, :string
  attribute :experience_level, :string
  
  validates :job_description, presence: true, length: { minimum: 50 }
  validates :target_role, presence: true, length: { minimum: 2 }
  
  def optimize
    messages = build_optimization_messages
    generate_completion(
      messages: messages,
      model: GPT_4_MODEL,
      max_tokens: 3000,
      temperature: 0.3
    )
  end
  
  def extract_keywords
    messages = build_keyword_extraction_messages
    generate_completion(
      messages: messages,
      model: GPT_4_MINI_MODEL,
      max_tokens: 500,
      temperature: 0.2
    )
  end
  
  def ats_score
    messages = build_ats_scoring_messages
    generate_completion(
      messages: messages,
      model: GPT_4_MINI_MODEL,
      max_tokens: 800,
      temperature: 0.1
    )
  end
  
  private
  
  def build_optimization_messages
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt
    
    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]
  end
  
  def build_system_prompt
    <<~PROMPT
      You are an expert ATS (Applicant Tracking System) resume optimizer and career consultant with 15+ years of experience helping professionals land their dream jobs.
      
      Your expertise includes:
      - ATS optimization and keyword placement
      - Industry-specific terminology and requirements
      - Achievement quantification and impact demonstration
      - Modern resume formatting and structure
      - Recruiter psychology and hiring trends
      
      CRITICAL REQUIREMENTS:
      1. Maintain factual accuracy - never fabricate experience or skills
      2. Focus on ATS-friendly formatting and keyword optimization
      3. Quantify achievements with specific metrics where possible
      4. Use industry-standard terminology for the target role
      5. Ensure readability for both ATS systems and human reviewers
      6. Prioritize relevance to the specific job description provided
      7. Consider regional preferences for #{user_country || 'US'} job market
      
      Format your response as a complete, polished resume ready for submission.
    PROMPT
  end
  
  def build_user_prompt
    <<~PROMPT
      ORIGINAL RESUME:
      #{content}
      
      JOB DESCRIPTION:
      #{job_description}
      
      TARGET ROLE: #{target_role}
      INDUSTRY: #{industry || 'Not specified'}
      EXPERIENCE LEVEL: #{experience_level || 'Not specified'}
      
      Please optimize this resume for the specific job posting. Focus on:
      1. Incorporating relevant keywords from the job description naturally
      2. Highlighting the most relevant experience for this role
      3. Quantifying achievements with specific metrics where possible
      4. Improving ATS compatibility and keyword density
      5. Maintaining the candidate's authentic voice and experience
      6. Ensuring the resume passes ATS screening for this specific job
      
      Provide the optimized resume in a clean, professional format.
    PROMPT
  end
  
  def build_keyword_extraction_messages
    [
      {
        role: "system",
        content: "You are an ATS keyword extraction expert. Extract the most important keywords and phrases from job descriptions that should be included in resumes for optimal ATS scoring."
      },
      {
        role: "user",
        content: "Extract the top 20 most important keywords and phrases from this job description that would improve ATS scores:\n\n#{job_description}\n\nReturn as a comma-separated list, prioritized by importance."
      }
    ]
  end
  
  def build_ats_scoring_messages
    [
      {
        role: "system",
        content: "You are an ATS scoring expert. Analyze resumes against job descriptions and provide detailed ATS compatibility scores and improvement suggestions."
      },
      {
        role: "user",
        content: <<~PROMPT
          RESUME:
          #{content}
          
          JOB DESCRIPTION:
          #{job_description}
          
          Provide an ATS compatibility analysis including:
          1. Overall ATS Score (0-100)
          2. Keyword Match Percentage
          3. Top 5 missing keywords that should be added
          4. Formatting issues that might hurt ATS parsing
          5. Specific recommendations for improvement
          
          Format as structured analysis with clear scores and actionable feedback.
        PROMPT
      }
    ]
  end
end