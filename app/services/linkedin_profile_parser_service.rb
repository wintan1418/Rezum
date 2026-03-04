class LinkedinProfileParserService
  attr_reader :text

  # LinkedIn page chrome and UI noise to strip out
  NOISE_PATTERNS = [
    /\APage \d+ of \d+\z/i,
    /\ALinkedIn\z/i,
    /\Alinkedin\.com\/in\//i,
    /\Awww\.linkedin\.com/i,
    /\AContact\z/i,
    /\ATop Skills\z/i,
    /\AMessage\z/i,
    /\AConnect\z/i,
    /\AFollow\z/i,
    /\AMore\z/i,
    /\AOpen to\z/i,
    /\AOpen to work\z/i,
    /\ASave to PDF\z/i,
    /\AShow all \d+/i,
    /\ASee all \d+/i,
    /\ASee more\z/i,
    /\ASee less\z/i,
    /\AShow more\z/i,
    /\AShow less\z/i,
    /\A\d+ connections?\z/i,
    /\A\d+ followers?\z/i,
    /\A\d+ mutual connections?\z/i,
    /\A\d+ people also viewed\z/i,
    /\APeople also viewed\z/i,
    /\APeople you may know\z/i,
    /\AEdit profile\z/i,
    /\AAdd to profile\z/i,
    /\AEndorsements?\z/i,
    /\A\d+ endorsements?\z/i,
    /\ARecommendations?\z/i,
    /\AGiven\z/i,
    /\AReceived\z/i,
    /\AActivity\z/i,
    /\A\d+ posts?\z/i,
    /\AShow all activity\z/i,
    /\AView full profile\z/i,
    /\ASign in\z/i,
    /\AJoin now\z/i,
    /\AReport this profile\z/i,
    /\AAbout this profile\z/i,
    /\Ahttps?:\/\//,
    /\A\(LinkedIn\)\z/i,
    /\AAnalytics\z/i,
    /\AProfile viewers\z/i,
    /\APost impressions\z/i,
    /\ASearch appearances\z/i,
    /\AResources\z/i,
    /\ACreator mode\z/i,
    /\AMy Network\z/i,
    /\AJobs\z/i,
    /\AMessaging\z/i,
    /\ANotifications\z/i,
    /\AHome\z/i,
  ].freeze

  # Known LinkedIn PDF section headers
  PDF_SECTION_HEADERS = {
    "summary" => /\A(Summary|About)\z/i,
    "experience" => /\AExperience\z/i,
    "education" => /\AEducation\z/i,
    "skills" => /\A(Skills|Top Skills)\z/i,
    "certifications" => /\A(Certifications?|Licenses?\s*&?\s*Certifications?)\z/i,
    "languages" => /\ALanguages?\z/i,
    "awards" => /\A(Awards?|Honors?\s*&?\s*Awards?)\z/i,
    "projects" => /\AProjects?\z/i,
    "volunteer" => /\A(Volunteer\s*Experience|Volunteer)\z/i,
    "publications" => /\APublications?\z/i,
    "courses" => /\ACourses?\z/i,
  }.freeze

  def initialize(text)
    @text = text.to_s.strip
  end

  def parse
    cleaned = clean_text
    sections = []
    position = 0

    # Extract name and headline from the top
    name = extract_name(cleaned)
    headline = extract_headline(cleaned)

    # Parse each section
    parsed_blocks = split_into_sections(cleaned)

    # Summary/About
    summary_text = parsed_blocks["summary"]
    if summary_text.present?
      # Clean summary: remove noise lines
      clean_summary = clean_section_text(summary_text)
      if clean_summary.present? && clean_summary.length > 10
        sections << { section_type: "summary", content: { "text" => clean_summary }, position: position }
        position += 1
      end
    end

    # Experience
    exp_text = parsed_blocks["experience"]
    if exp_text.present?
      entries = parse_experience(exp_text)
      if entries.any?
        sections << { section_type: "experience", content: { "entries" => entries }, position: position }
        position += 1
      end
    end

    # Education
    edu_text = parsed_blocks["education"]
    if edu_text.present?
      entries = parse_education(edu_text)
      if entries.any?
        sections << { section_type: "education", content: { "entries" => entries }, position: position }
        position += 1
      end
    end

    # Skills
    skills_text = parsed_blocks["skills"]
    if skills_text.present?
      items = parse_skills(skills_text)
      if items.any?
        sections << { section_type: "skills", content: { "items" => items }, position: position }
        position += 1
      end
    end

    # Certifications
    cert_text = parsed_blocks["certifications"]
    if cert_text.present?
      items = parse_list_items(cert_text)
      if items.any?
        sections << { section_type: "certifications", content: { "items" => items }, position: position }
        position += 1
      end
    end

    # Languages
    lang_text = parsed_blocks["languages"]
    if lang_text.present?
      items = parse_list_items(lang_text)
      if items.any?
        sections << { section_type: "languages", content: { "items" => items }, position: position }
        position += 1
      end
    end

    {
      name: name,
      headline: headline,
      sections: sections,
      raw_text: cleaned
    }
  end

  private

  def clean_text
    lines = text.lines.map(&:strip)

    # Remove noise lines
    lines = lines.reject do |line|
      next true if line.blank?
      next true if NOISE_PATTERNS.any? { |pat| line.match?(pat) }
      next true if line.length < 2
      # Remove lines that are just numbers (page numbers, counts)
      next true if line.match?(/\A\d+\z/)
      # Remove email-like lines by themselves (LinkedIn contact info we don't need as section)
      false
    end

    lines.join("\n")
  end

  def extract_name(cleaned)
    # In LinkedIn PDF, the name is typically the first line
    first_lines = cleaned.lines.map(&:strip).reject(&:blank?).first(5)
    return nil if first_lines.empty?

    # Name is usually the first line, skip if it looks like a section header
    candidate = first_lines.first
    return candidate unless is_section_header?(candidate)
    first_lines[1]
  end

  def extract_headline(cleaned)
    # Headline is usually the second non-blank line (right after name)
    non_blank = cleaned.lines.map(&:strip).reject(&:blank?)
    return nil if non_blank.length < 2

    candidate = non_blank[1]
    # Skip if it's a section header or looks like contact info
    return nil if is_section_header?(candidate)
    return nil if candidate.match?(/\A[\w.+-]+@[\w.-]+\z/) # email
    candidate
  end

  def split_into_sections(cleaned)
    lines = cleaned.lines.map { |l| l.strip }
    blocks = {}
    current_section = nil
    current_lines = []

    lines.each do |line|
      next if line.blank?

      # Check if this line is a section header
      section_key = detect_section_header(line)
      if section_key
        # Save previous section
        if current_section
          blocks[current_section] = current_lines.join("\n").strip
        end
        current_section = section_key
        current_lines = []
      elsif current_section
        current_lines << line
      end
      # Lines before any section header are ignored (name, headline, contact)
    end

    # Save last section
    if current_section
      blocks[current_section] = current_lines.join("\n").strip
    end

    blocks
  end

  def detect_section_header(line)
    PDF_SECTION_HEADERS.each do |key, pattern|
      return key if line.match?(pattern)
    end
    nil
  end

  def is_section_header?(line)
    PDF_SECTION_HEADERS.values.any? { |pat| line.match?(pat) }
  end

  def clean_section_text(text)
    lines = text.lines.map(&:strip).reject(&:blank?)
    lines = lines.reject { |l| noise_line?(l) }
    lines.join("\n").strip
  end

  def noise_line?(line)
    NOISE_PATTERNS.any? { |pat| line.match?(pat) }
  end

  def parse_experience(text)
    entries = []
    current = nil

    text.lines.map(&:strip).each do |line|
      next if line.blank?
      next if noise_line?(line)

      # Date range pattern: "Jan 2020 - Present", "2018 - 2022", "Mar 2019 - Dec 2021 · 2 yrs 9 mos"
      if line.match?(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|january|february|march|april|may|june|july|august|september|october|november|december|\d{4})\b.*[-–—]\s*(present|\d{4}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|january|february|march|april|may|june|july|august|september|october|november|december)/i)
        if current
          # Extract just the date range, drop duration after "·"
          current["dates"] = line.split("·").first&.strip || line
        end
      # Company line: contains "·" with employment type like "Full-time", "Part-time", "Contract", etc.
      elsif line.match?(/·/) && line.match?(/full.?time|part.?time|contract|self.?employed|freelance|internship|seasonal|temporary/i)
        if current && current["company"].blank?
          current["company"] = line.split("·").first&.strip
        end
      # Company line without employment type but with "·"
      elsif line.match?(/·/) && !line.start_with?("•") && !line.start_with?("-") && current && current["company"].blank?
        current["company"] = line.split("·").first&.strip
      # Bullet points
      elsif line.match?(/\A[•\-–—]\s/)
        current["bullets"] << line.sub(/\A[•\-–—]\s*/, "").strip if current
      # Duration line like "2 yrs 9 mos" or "1 yr" — skip
      elsif line.match?(/\A\d+\s*(yr|mo|year|month)s?\b/i)
        next
      # Location line like "San Francisco, CA" or "Lagos, Nigeria" — skip
      elsif line.match?(/\A[A-Z][a-z]+(?:\s[A-Z][a-z]+)*,\s*[A-Z]{2,}\z/) || line.match?(/\A[A-Z][a-z]+(?:\s[A-Z][a-z]+)*,\s*[A-Z][a-z]+/)
        next
      # Likely a new job title
      elsif line.length > 2 && line.length < 100
        entries << current if current && current["title"].present?
        current = { "title" => line, "company" => "", "dates" => "", "bullets" => [] }
      end
    end

    entries << current if current && current["title"].present?

    # Clean up: remove entries where title looks like noise
    entries.reject do |e|
      e["title"].match?(/\A\d+/) ||
      e["title"].length < 3 ||
      noise_line?(e["title"])
    end
  end

  def parse_education(text)
    entries = []
    current = nil

    text.lines.map(&:strip).each do |line|
      next if line.blank?
      next if noise_line?(line)

      # School name: contains university/college/institute/school OR is the first line for a new entry
      if line.match?(/\b(university|college|institute|school|academy|polytechnic|universit[ée])\b/i)
        entries << current if current
        current = { "degree" => "", "school" => line, "dates" => "", "details" => "" }
      elsif current.nil? && line.length > 3 && !line.match?(/\A\d/)
        # First entry might not have "university" in name
        current = { "degree" => "", "school" => line, "dates" => "", "details" => "" }
      elsif current
        if line.match?(/\b\d{4}\b/)
          current["dates"] = line.split("·").first&.strip || line
        elsif current["degree"].blank? && line.length > 2
          current["degree"] = line.split("·").first&.strip || line
        elsif line.length > 2
          current["details"] = [current["details"], line].reject(&:blank?).join(". ")
        end
      end
    end

    entries << current if current

    # Clean up
    entries.reject do |e|
      e["school"].blank? ||
      e["school"].length < 3 ||
      noise_line?(e["school"])
    end
  end

  def parse_skills(text)
    lines = text.lines.map(&:strip).reject(&:blank?)

    lines
      .reject { |l| noise_line?(l) }
      .reject { |l| l.match?(/endorsed|endorsement|\d+\s*skill/i) }
      .reject { |l| l.match?(/\A\d+\z/) }
      .map { |l| l.split("·").first&.strip }
      .compact
      .reject { |s| s.length > 60 || s.length < 2 }
      .uniq
      .first(30)
  end

  def parse_list_items(text)
    lines = text.lines.map(&:strip).reject(&:blank?)

    lines
      .reject { |l| noise_line?(l) }
      .reject { |l| l.match?(/\A\d+\z/) }
      .reject { |l| l.match?(/issued|credential id|expir|see credential/i) && l.length < 30 }
      .map(&:strip)
      .reject { |l| l.length < 2 || l.length > 120 }
      .uniq
      .first(20)
  end
end
