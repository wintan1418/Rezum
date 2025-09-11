class CoverLetterGeneratorService < AiService
  attribute :resume_content, :string
  attribute :job_description, :string
  attribute :company_name, :string
  attribute :hiring_manager_name, :string
  attribute :target_role, :string
  attribute :tone, :string, default: 'professional'
  attribute :length, :string, default: 'medium'
  
  validates :resume_content, presence: true, length: { minimum: 100 }
  validates :job_description, presence: true, length: { minimum: 50 }
  validates :company_name, presence: true, length: { minimum: 2 }
  validates :target_role, presence: true, length: { minimum: 2 }
  validates :tone, inclusion: { in: %w[professional friendly confident casual enthusiastic] }
  validates :length, inclusion: { in: %w[short medium long] }
  
  def generate
    messages = build_generation_messages
    
    # Use Claude for more creative writing, OpenAI as fallback
    provider = determine_best_provider
    model = provider == :anthropic ? CLAUDE_3_5_SONNET : GPT_4_MODEL
    
    generate_completion(
      messages: messages,
      model: model,
      max_tokens: token_limit_for_length,
      temperature: temperature_for_tone,
      provider: provider
    )
  end
  
  def generate_variations(count: 3)
    variations = []
    
    count.times do |i|
      # Alternate between providers for variety
      current_provider = i.even? ? :openai : :anthropic
      
      messages = build_variation_messages(i + 1)
      
      variation = with_provider(current_provider).generate_completion(
        messages: messages,
        max_tokens: token_limit_for_length,
        temperature: temperature_for_tone + (i * 0.1) # Slight temperature variation
      )
      
      variations << {
        version: i + 1,
        content: variation,
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
    regional_context = user_country == 'US' ? 'American' : (user_country&.in?(['UK', 'GB']) ? 'British' : 'International')
    
    <<~PROMPT
      You are an expert cover letter writer and career consultant with 15+ years of experience helping professionals secure interviews and job offers.
      
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
      4. Incorporate specific details from the job description naturally
      5. Highlight 2-3 most relevant achievements with quantified impact
      6. Include a compelling opening that grabs attention
      7. End with a confident call-to-action
      8. Ensure ATS compatibility with relevant keywords
      9. Follow #{regional_context} business letter conventions
      10. Never fabricate experience or skills not in the original resume
      
      Format as a complete, ready-to-send cover letter with proper structure.
    PROMPT
  end
  
  def build_user_prompt
    hiring_manager_greeting = hiring_manager_name.present? ? 
      "Dear #{hiring_manager_name}," : 
      "Dear Hiring Manager,"
    
    <<~PROMPT
      CANDIDATE'S RESUME:
      #{resume_content}
      
      JOB POSTING:
      #{job_description}
      
      POSITION: #{target_role} at #{company_name}
      GREETING: #{hiring_manager_greeting}
      TONE: #{tone.capitalize}
      LENGTH: #{length.capitalize} (#{word_count_for_length} words)
      
      Create a compelling cover letter that:
      1. Opens with a strong, attention-grabbing first paragraph
      2. Demonstrates clear understanding of the role and company
      3. Highlights the candidate's most relevant experience and achievements
      4. Shows genuine enthusiasm for the opportunity
      5. Includes specific examples with quantified results where possible
      6. Addresses key requirements from the job posting
      7. Concludes with a confident call-to-action
      
      The cover letter should feel personal, authentic, and tailored specifically to this opportunity.
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
  
  def determine_best_provider
    # Use Claude for creative writing, OpenAI for structured content
    case tone
    when 'creative', 'enthusiastic', 'friendly'
      :anthropic
    when 'professional', 'confident'
      :openai
    else
      :openai
    end
  end
  
  def word_count_for_length
    case length
    when 'short'
      '200-250'
    when 'medium'
      '300-400'
    when 'long'
      '450-600'
    else
      '300-400'
    end
  end
  
  def token_limit_for_length
    case length
    when 'short'
      400
    when 'medium'
      600
    when 'long'
      900
    else
      600
    end
  end
  
  def temperature_for_tone
    case tone
    when 'professional'
      0.3
    when 'confident'
      0.4
    when 'friendly'
      0.6
    when 'enthusiastic'
      0.7
    when 'casual'
      0.8
    else
      0.4
    end
  end
end