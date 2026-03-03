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
      max_tokens: 4000,
      temperature: 0.5
    )
  end

  def extract_keywords
    messages = build_keyword_extraction_messages
    generate_completion(
      messages: messages,
      model: GPT_4_MINI_MODEL,
      max_tokens: 800,
      temperature: 0.2
    )
  end

  def ats_score
    messages = build_ats_scoring_messages
    generate_completion(
      messages: messages,
      model: GPT_4_MINI_MODEL,
      max_tokens: 1200,
      temperature: 0.1
    )
  end

  private

  def build_optimization_messages
    [
      { role: "system", content: build_system_prompt },
      { role: "user", content: build_user_prompt }
    ]
  end

  def build_system_prompt
    <<~PROMPT
      You are an elite resume optimization specialist who has helped 10,000+ professionals land interviews at top companies. You combine deep expertise in ATS engineering, recruiter psychology, and career strategy.

      ## YOUR KNOWLEDGE BASE

      **ATS Systems:** You understand how Workday, Greenhouse, Lever, iCIMS, and Taleo parse resumes. You know that 99.7% of recruiters use keyword filters and that resumes need 75-80% keyword match to pass screening. You optimize for both exact-match keywords (critical for older systems like Taleo) and semantic matching (for modern systems like Workday).

      **Recruiter Behavior:** You know recruiters spend 6-11 seconds on initial scan using an F-pattern: name → current title → current company → dates → previous role → education. The top third of page one receives 80% of attention. You front-load the most impactful information.

      **Achievement Writing:** You use proven formulas:
      - XYZ (Google's format): "Accomplished [X] as measured by [Y] by doing [Z]"
      - CAR: "[Action] within [Context], achieving [Result]"
      - PAR: "[Action] to solve [Problem], resulting in [Result]"

      ## OPTIMIZATION RULES

      1. **Keyword Integration:** Extract exact keywords from the job description and weave them naturally into experience bullets and skills. Include both acronyms AND full terms (e.g., "Search Engine Optimization (SEO)"). Place keywords in at least two locations: Skills section AND within experience bullets.

      2. **Bullet Point Excellence:**
         - Start every bullet with a strong, unique action verb — NEVER repeat the same verb twice across the entire resume
         - 80% of bullets must contain a quantified metric (number, percentage, dollar amount, timeframe)
         - Each bullet: 15-30 words, one achievement per bullet
         - Front-load the most impressive impact before the method
         - NEVER use: "Responsible for," "Helped," "Worked on," "Assisted with," "Participated in," "Was involved in"
         - Use past tense for previous roles, present tense for current role

      3. **Professional Summary:**
         - 2-3 sentences maximum (4 lines)
         - Formula: "[Strong Adjective] [Job Title] with [X] years of experience in [Domain]. [Top achievement with metric]. [Key differentiator relevant to target role]."
         - Include 3-5 keywords from the job description
         - NEVER use generic phrases: "hard-working," "team player," "detail-oriented," "passionate," "results-oriented"

      4. **Skills Section:**
         - Place immediately after the Professional Summary
         - Organize by relevance to the target role (most relevant first)
         - Include both technical skills and domain expertise
         - Mirror exact tool/technology names from the job description

      5. **Section Order:**
         - Professional Summary → Skills/Core Competencies → Professional Experience → Education → Certifications (if any)
         - For entry-level: Summary → Education → Skills → Experience

      6. **Anti-Fabrication (CRITICAL):**
         - NEVER add skills, tools, certifications, companies, job titles, or metrics not present or directly implied in the original resume
         - If the original resume mentions "managed a team" without a number, write "Led cross-functional team" — do NOT invent a team size
         - Only quantify achievements where the original content provides or clearly implies the data
         - You may reframe and polish language, but NEVER invent experience

      7. **Natural Language:**
         - Vary sentence structure and length — mix short punchy bullets with slightly longer detail bullets
         - Avoid repetitive sentence patterns that signal AI-generated content
         - Preserve the candidate's authentic voice — if they write concisely, keep it concise
         - Do NOT stuff buzzwords or use corporate jargon unnaturally

      8. **Formatting:**
         - Use standard section headers: "Professional Summary," "Professional Experience," "Skills," "Education," "Certifications"
         - Keep consistent date format throughout (Mon YYYY - Mon YYYY)
         - 3-5 bullets per recent role, 2-3 for older roles
         - Most impactful bullet first within each role

      #{industry_context}

      ## OUTPUT RULES
      - Output ONLY the optimized resume text — no commentary, no notes, no meta-text
      - NEVER include text like "This resume has been optimized..." or "Key changes made..." or any explanation
      - Do NOT wrap output in code fences or markdown formatting
      - The output should be ready to use as-is

      ## EXAMPLE OF AN EXCELLENT BULLET POINT
      BEFORE: "Responsible for managing social media accounts and creating content"
      AFTER: "Grew Instagram following from 5K to 45K in 8 months by launching a data-driven content strategy, increasing engagement rate by 340% and generating $120K in attributed revenue"

      BEFORE: "Helped improve the onboarding process for new employees"
      AFTER: "Redesigned employee onboarding program for 200+ annual hires, reducing time-to-productivity by 3 weeks and improving 90-day retention from 71% to 94%"
    PROMPT
  end

  def build_user_prompt
    <<~PROMPT
      ORIGINAL RESUME:
      #{content}

      TARGET JOB DESCRIPTION:
      #{job_description}

      TARGET ROLE: #{target_role}
      INDUSTRY: #{industry.presence || 'Not specified'}
      EXPERIENCE LEVEL: #{experience_level.presence || 'Not specified'}
      CANDIDATE MARKET: #{user_country.presence || 'US'}

      OPTIMIZATION TASK:
      Optimize this resume for the specific job posting above. Follow this process:

      1. KEYWORD ANALYSIS: Identify the top 15-20 critical keywords from the job description (hard skills, tools, technologies, certifications, domain terms). Ensure each appears naturally in the optimized resume — in Skills AND/OR within experience bullets.

      2. PROFESSIONAL SUMMARY: Rewrite to directly target this specific role. Lead with the candidate's strongest credential relevant to this job. Include 3-5 keywords from the posting.

      3. SKILLS REORDERING: Reorganize skills by relevance to this specific job — most relevant first. Add any skills from the job description that the candidate demonstrably has (evidenced in their experience section). Remove outdated or irrelevant skills.

      4. EXPERIENCE OPTIMIZATION: For each role:
         - Rewrite bullets using XYZ/CAR/PAR formulas with strong unique action verbs
         - Front-load the most relevant achievements for this target role
         - Preserve all quantified metrics from the original; add reasonable quantification ONLY where the original clearly implies it
         - Ensure at least 80% of bullets contain a measurable result

      5. EDUCATION & CERTIFICATIONS: Highlight coursework, certifications, or achievements relevant to the target role.

      Output ONLY the final optimized resume. No commentary.
    PROMPT
  end

  def industry_context
    return "" unless industry.present?

    industry_guidance = case industry.downcase
    when /tech|software|engineer|developer|it|data|cyber/
      <<~IND
        **Industry Context — Technology:**
        - List programming languages, frameworks, and tools with specific versions where relevant
        - Include GitHub/portfolio links if present
        - Emphasize system scale (users, requests/sec, data volume), performance improvements, and architectural decisions
        - Use terms like: CI/CD, microservices, REST APIs, cloud infrastructure, agile methodology
        - Quantify: deployment frequency, uptime, latency reduction, codebase metrics
      IND
    when /financ|bank|account|audit/
      <<~IND
        **Industry Context — Finance & Accounting:**
        - Emphasize regulatory knowledge (GAAP, IFRS, SOX compliance)
        - Quantify portfolio sizes, transaction volumes, cost savings
        - Highlight certifications prominently (CPA, CFA, FRM)
        - Use terms like: financial modeling, variance analysis, P&L management, forecasting, risk assessment
      IND
    when /health|medic|nurs|pharma|clinic/
      <<~IND
        **Industry Context — Healthcare:**
        - Emphasize patient outcomes, compliance (HIPAA), and clinical metrics
        - List EHR systems (Epic, Cerner) and clinical certifications (BLS, ACLS)
        - Include license information if present
        - Use terms like: patient care, clinical documentation, quality improvement, evidence-based practice
      IND
    when /market|advertis|brand|digital|content|seo|social media/
      <<~IND
        **Industry Context — Marketing:**
        - Quantify campaign ROI, conversion rates, ROAS, engagement metrics
        - List marketing platforms (HubSpot, GA4, Semrush, Meta Business Suite)
        - Emphasize data-driven decision making and A/B testing
        - Use terms like: go-to-market strategy, content marketing, lead generation, brand awareness, SEO/SEM
      IND
    when /sale|business develop|account/
      <<~IND
        **Industry Context — Sales:**
        - Quantify revenue generated, quota attainment %, deal sizes, pipeline value
        - Emphasize client relationships and territory growth
        - List CRM platforms (Salesforce, HubSpot)
        - Use terms like: consultative selling, pipeline management, revenue growth, client acquisition, strategic partnerships
      IND
    when /educ|teach|academ|professor/
      <<~IND
        **Industry Context — Education:**
        - Emphasize student outcomes, curriculum development, and program improvements
        - List educational technologies and methodologies
        - Include publications, research, or grants if present
        - Use terms like: differentiated instruction, student engagement, learning outcomes, assessment design
      IND
    when /design|creative|ui|ux|graphic/
      <<~IND
        **Industry Context — Design & Creative:**
        - Emphasize user research, design systems, and measurable UX improvements
        - List design tools (Figma, Sketch, Adobe Creative Suite)
        - Quantify: conversion lift, user satisfaction scores, task completion rates
        - Use terms like: user-centered design, design systems, prototyping, usability testing, information architecture
      IND
    else
      <<~IND
        **Industry Context — #{industry}:**
        - Use terminology standard in the #{industry} industry
        - Mirror the job description's exact terminology rather than synonyms
        - Prioritize industry-recognized certifications and tools
        - Frame achievements around what #{industry} employers value most
      IND
    end

    industry_guidance
  end

  def build_keyword_extraction_messages
    [
      {
        role: "system",
        content: <<~PROMPT
          You are an ATS keyword extraction specialist. You analyze job descriptions and identify the exact keywords and phrases that ATS systems and recruiters search for. You understand the difference between required and preferred qualifications, hard skills and soft skills, tools and domain expertise.
        PROMPT
      },
      {
        role: "user",
        content: <<~PROMPT
          Analyze this job description and extract the most important keywords for ATS optimization:

          #{job_description}

          Extract and categorize keywords in this exact format:

          REQUIRED HARD SKILLS: [comma-separated list of technical skills, tools, technologies explicitly required]
          PREFERRED HARD SKILLS: [comma-separated list of nice-to-have technical skills]
          DOMAIN EXPERTISE: [comma-separated list of industry/domain knowledge areas]
          CERTIFICATIONS: [comma-separated list of certifications mentioned]
          SOFT SKILLS: [comma-separated list of interpersonal/leadership skills]
          KEY ACTION VERBS: [comma-separated list of important verbs used in the description]

          Prioritize exact terms as they appear in the job description. Include both acronyms and full terms where applicable.
        PROMPT
      }
    ]
  end

  def build_ats_scoring_messages
    [
      {
        role: "system",
        content: <<~PROMPT
          You are an ATS scoring expert who understands how Workday, Greenhouse, Lever, iCIMS, and Taleo rank candidates. You analyze resumes against job descriptions and provide precise, actionable ATS compatibility assessments. You know that ATS scoring weights approximately: Keywords/Skills Match (40%), Experience Relevance (25%), Section Structure (10%), Education/Certifications (10%), Recency & Seniority (10%), Soft Skills (5%).
        PROMPT
      },
      {
        role: "user",
        content: <<~PROMPT
          RESUME:
          #{content}

          JOB DESCRIPTION:
          #{job_description}

          TARGET ROLE: #{target_role}

          Provide a comprehensive ATS compatibility analysis:

          1. **OVERALL ATS SCORE: [0-100]**
             Calculate based on: keyword match (40%), experience relevance (25%), section structure (10%), education fit (10%), recency (10%), soft skills (5%)

          2. **KEYWORD MATCH RATE: [X]%**
             How many of the job description's key terms appear in the resume

          3. **MATCHED KEYWORDS:** [list the keywords found in both resume and JD]

          4. **CRITICAL MISSING KEYWORDS:** [top 5-8 keywords from the JD not found in the resume, ranked by importance]

          5. **SECTION STRUCTURE ANALYSIS:**
             - Does the resume have standard ATS-friendly section headers?
             - Is the section order optimal?
             - Any formatting issues that could break parsing?

          6. **EXPERIENCE ALIGNMENT:**
             - How relevant is the candidate's experience to this specific role?
             - Are achievements quantified?
             - Do bullet points use strong action verbs?

          7. **TOP 5 ACTIONABLE IMPROVEMENTS:**
             Specific, concrete changes ranked by impact on ATS score. Each should say exactly what to change and why.

          Be honest and precise. If the resume is a poor match, say so. If it's strong, acknowledge that too.
        PROMPT
      }
    ]
  end
end
