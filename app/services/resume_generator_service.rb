class ResumeGeneratorService < AiService
  attribute :full_name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :location, :string
  attribute :target_role, :string
  attribute :industry, :string
  attribute :experience_level, :string
  attribute :experiences, default: -> { [] }    # Array of hashes
  attribute :educations, default: -> { [] }     # Array of hashes
  attribute :skills, :string
  attribute :certifications, :string
  attribute :additional_info, :string

  validates :full_name, presence: true
  validates :target_role, presence: true

  def generate
    messages = build_generation_messages
    raw = generate_completion(
      messages: messages,
      model: GPT_4_MODEL,
      max_tokens: 4000,
      temperature: 0.5
    )
    parse_ai_response(raw)
  end

  def create_resume!(user)
    sections_data = generate

    resume = user.resumes.create!(
      original_content: build_plain_text_content(sections_data),
      target_role: target_role,
      industry: industry,
      experience_level: experience_level,
      status: "draft",
      template: "professional"
    )

    position = 0
    sections_data.each do |section|
      resume.resume_sections.create!(
        section_type: section[:type],
        content: section[:content],
        position: position,
        visible: true
      )
      position += 1
    end

    resume
  end

  private

  def build_generation_messages
    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]
  end

  def system_prompt
    <<~PROMPT
      You are an elite resume writer who has crafted resumes for 10,000+ professionals across every industry. You transform raw career information into polished, ATS-optimized resumes that get interviews.

      ## YOUR APPROACH

      **Professional Summary:** Write a compelling 2-3 sentence summary using this formula:
      "[Strong Adjective] [Job Title] with [X] years of experience in [Domain]. [Signature achievement with metric if available]. [Key differentiator or specialized expertise relevant to target role]."
      - NEVER use generic phrases: "hard-working," "team player," "detail-oriented," "passionate," "results-oriented," "go-getter"
      - Tailor specifically to the target role

      **Experience Bullets:** Transform raw responsibilities into achievement-oriented bullets:
      - Use Google's XYZ formula: "Accomplished [X] as measured by [Y] by doing [Z]"
      - Start every bullet with a strong, UNIQUE action verb — never repeat the same verb across the resume
      - 80% of bullets should contain a quantified metric (number, percentage, dollar amount, timeframe, team size)
      - Each bullet: 15-30 words, one achievement per bullet
      - 3-5 bullets per role, most impactful first
      - NEVER use: "Responsible for," "Helped with," "Worked on," "Assisted," "Participated in"

      **Power Action Verbs (use these):**
      Leadership: Spearheaded, Directed, Orchestrated, Championed, Pioneered, Mobilized
      Growth: Accelerated, Expanded, Generated, Captured, Maximized, Scaled
      Efficiency: Streamlined, Optimized, Automated, Consolidated, Eliminated, Reduced
      Creation: Architected, Engineered, Designed, Developed, Built, Launched, Established
      Analysis: Diagnosed, Forecasted, Identified, Quantified, Evaluated

      **Quantification Techniques:**
      When the user provides vague descriptions, quantify using context clues:
      - "managed a team" → estimate scope from company/role context, but mark clearly
      - If you CANNOT reasonably infer a number, use scope language instead: "Led cross-functional team" or "Managed enterprise client portfolio"
      - Use scale indicators: daily/weekly/monthly volume, budget ranges, geographic scope, number of stakeholders
      - NEVER fabricate specific numbers that aren't supported by the provided information

      **Skills Section:**
      - Organize by category and relevance to the target role (most relevant first)
      - Include both technical and domain skills
      - Mirror industry-standard terminology

      ## ANTI-FABRICATION RULES (CRITICAL)
      - NEVER add skills, tools, companies, job titles, degrees, or certifications the user didn't provide
      - NEVER invent specific metrics (e.g., "increased sales by 47%") unless the user explicitly stated it
      - You MAY polish language, reorder for impact, and add reasonable context
      - You MAY infer approximate scope from role/company context (e.g., a "Marketing Manager" likely managed campaigns)
      - When in doubt, keep it factual and use qualitative language over fabricated numbers

      ## OUTPUT FORMAT
      Respond with ONLY a valid JSON array. No markdown code fences. No commentary.

      Each element is an object with:
      - "type": one of "summary", "experience", "education", "skills", "certifications"
      - "content": section data in these formats:

      summary: { "text": "Professional summary paragraph" }
      experience: { "entries": [{ "title": "Job Title", "company": "Company Name", "dates": "Mon YYYY - Mon YYYY", "bullets": ["Achievement 1", "Achievement 2", ...] }] }
      education: { "entries": [{ "degree": "Degree Name", "school": "School Name", "dates": "YYYY - YYYY" }] }
      skills: { "items": ["Skill 1", "Skill 2", ...] }
      certifications: { "items": ["Cert 1", "Cert 2", ...] }

      Always include: summary, experience, education, skills.
      Only include certifications if the user provided them.

      ## EXAMPLE OF EXCELLENT OUTPUT

      For a "Marketing Manager" with "managed social media, created content, ran email campaigns":

      BAD bullet: "Responsible for managing social media accounts"
      GOOD bullet: "Grew organic social media following by 3x through a data-driven content calendar, increasing monthly engagement rate to 4.2%"

      BAD bullet: "Helped with email marketing campaigns"
      GOOD bullet: "Launched automated email nurture sequences for 15K+ subscriber base, achieving 32% open rate and 8% click-through rate"
    PROMPT
  end

  def user_prompt
    parts = []
    parts << "TARGET ROLE: #{target_role}"
    parts << "INDUSTRY: #{industry}" if industry.present?
    parts << "EXPERIENCE LEVEL: #{experience_level}" if experience_level.present?
    parts << ""
    parts << "CANDIDATE: #{full_name}"
    parts << "EMAIL: #{email}" if email.present?
    parts << "PHONE: #{phone}" if phone.present?
    parts << "LOCATION: #{location}" if location.present?
    parts << ""

    if experiences.present? && experiences.any?
      parts << "WORK EXPERIENCE:"
      experiences.each_with_index do |exp, i|
        parts << "  Job #{i + 1}:"
        parts << "    Title: #{exp['title'] || exp[:title]}"
        parts << "    Company: #{exp['company'] || exp[:company]}"
        parts << "    Dates: #{exp['dates'] || exp[:dates]}"
        parts << "    What they did: #{exp['description'] || exp[:description]}"
        parts << ""
      end
    end

    if educations.present? && educations.any?
      parts << "EDUCATION:"
      educations.each_with_index do |edu, i|
        parts << "  #{i + 1}. #{edu['degree'] || edu[:degree]} at #{edu['school'] || edu[:school]} (#{edu['dates'] || edu[:dates]})"
      end
      parts << ""
    end

    parts << "SKILLS: #{skills}" if skills.present?
    parts << "CERTIFICATIONS: #{certifications}" if certifications.present?
    parts << "ADDITIONAL INFO: #{additional_info}" if additional_info.present?

    parts << ""
    parts << "Transform this information into a polished, professional resume optimized for ATS systems and the #{target_role} role. Write a compelling professional summary, transform experience descriptions into achievement-oriented bullets using strong action verbs and metrics where supported by the data, and organize skills by relevance. Return ONLY the JSON array."

    parts.join("\n")
  end

  def parse_ai_response(raw)
    # Strip any markdown code fences
    cleaned = raw.gsub(/\A\s*```(?:json)?\s*\n?/, "").gsub(/\n?\s*```\s*\z/, "").strip

    sections = JSON.parse(cleaned)

    sections.map do |section|
      {
        type: section["type"],
        content: section["content"]
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error "ResumeGeneratorService JSON parse error: #{e.message}"
    Rails.logger.error "Raw response: #{raw}"
    build_fallback_sections
  end

  def build_fallback_sections
    sections = []

    sections << {
      type: "summary",
      content: { "text" => "Experienced #{experience_level || ''} professional targeting #{target_role} roles#{industry.present? ? " in the #{industry} industry" : ''}." }
    }

    if experiences.present? && experiences.any?
      entries = experiences.map do |exp|
        {
          "title" => (exp["title"] || exp[:title]).to_s,
          "company" => (exp["company"] || exp[:company]).to_s,
          "dates" => (exp["dates"] || exp[:dates]).to_s,
          "bullets" => (exp["description"] || exp[:description]).to_s.split(/[.\n]/).map(&:strip).reject(&:blank?)
        }
      end
      sections << { type: "experience", content: { "entries" => entries } }
    end

    if educations.present? && educations.any?
      entries = educations.map do |edu|
        {
          "degree" => (edu["degree"] || edu[:degree]).to_s,
          "school" => (edu["school"] || edu[:school]).to_s,
          "dates" => (edu["dates"] || edu[:dates]).to_s
        }
      end
      sections << { type: "education", content: { "entries" => entries } }
    end

    if skills.present?
      sections << { type: "skills", content: { "items" => skills.split(",").map(&:strip).reject(&:blank?) } }
    end

    if certifications.present?
      sections << { type: "certifications", content: { "items" => certifications.split(",").map(&:strip).reject(&:blank?) } }
    end

    sections
  end

  def build_plain_text_content(sections_data)
    lines = []
    lines << full_name
    lines << [ email, phone, location ].compact.reject(&:blank?).join(" | ")
    lines << ""

    sections_data.each do |section|
      lines << section[:type].upcase
      lines << "---"

      case section[:type]
      when "summary"
        lines << section[:content]["text"]
      when "experience"
        Array(section[:content]["entries"]).each do |entry|
          lines << "#{entry['title']} at #{entry['company']} (#{entry['dates']})"
          Array(entry["bullets"]).each { |b| lines << "  - #{b}" }
          lines << ""
        end
      when "education"
        Array(section[:content]["entries"]).each do |entry|
          lines << "#{entry['degree']} - #{entry['school']} (#{entry['dates']})"
        end
      when "skills"
        lines << Array(section[:content]["items"]).join(", ")
      when "certifications"
        Array(section[:content]["items"]).each { |c| lines << "  - #{c}" }
      end

      lines << ""
    end

    lines.join("\n")
  end
end
