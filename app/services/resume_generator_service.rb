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
      max_tokens: 3000,
      temperature: 0.4
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
      You are an expert resume writer and career consultant. You take raw career information and transform it into polished, professional resume content optimized for ATS systems.

      CRITICAL RULES:
      1. NEVER fabricate information — only polish and reword what is provided
      2. Use strong action verbs to start bullet points
      3. Quantify achievements where the data suggests it (add reasonable metrics)
      4. Keep language professional, concise, and impactful
      5. Tailor content to the target role and industry
      6. Output ONLY valid JSON — no markdown, no code fences, no commentary

      You must respond with a JSON array of section objects. Each object has:
      - "type": one of "summary", "experience", "education", "skills", "certifications"
      - "content": the section data (format depends on type, see below)

      SECTION CONTENT FORMATS:
      - summary: { "text": "Professional summary paragraph" }
      - experience: { "entries": [{ "title": "Job Title", "company": "Company", "dates": "Start - End", "bullets": ["Achievement 1", "Achievement 2", ...] }] }
      - education: { "entries": [{ "degree": "Degree Name", "school": "School Name", "dates": "Start - End" }] }
      - skills: { "items": ["Skill 1", "Skill 2", ...] }
      - certifications: { "items": ["Cert 1", "Cert 2", ...] }

      Always include: summary, experience, education, skills.
      Only include certifications if the user provided them.
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
        parts << "    Responsibilities: #{exp['description'] || exp[:description]}"
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
    parts << "Generate a polished, ATS-optimized resume. Write a compelling professional summary. Polish the experience bullet points with action verbs and metrics. Organize skills by relevance to the target role. Return ONLY the JSON array."

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
    lines << [email, phone, location].compact.reject(&:blank?).join(" | ")
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
