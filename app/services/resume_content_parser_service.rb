class ResumeContentParserService
  SECTION_PATTERNS = {
    "summary" => /\A\s*(summary|profile|objective|about\s*me|professional\s*summary|career\s*summary|personal\s*statement)\s*\z/i,
    "experience" => /\A\s*(experience|work\s*history|employment|professional\s*experience|work\s*experience|career\s*history)\s*\z/i,
    "education" => /\A\s*(education|academic|qualifications|degrees?|schooling)\s*\z/i,
    "skills" => /\A\s*(skills|technical\s*skills|core\s*competencies|competencies|proficiencies|expertise|technologies)\s*\z/i,
    "certifications" => /\A\s*(certifications?|licenses?|accreditations?|credentials?)\s*\z/i,
    "projects" => /\A\s*(projects?|portfolio|key\s*projects|selected\s*projects)\s*\z/i,
    "languages" => /\A\s*(languages?|language\s*skills)\s*\z/i,
    "awards" => /\A\s*(awards?|honors?|achievements?|recognition)\s*\z/i,
    "location" => /\A\s*(location|address|contact\s*info)\s*\z/i
  }.freeze

  BULLET_RE = /\A[\u2022\u2023\u25E6\u2043\u2219*•\-]\s+/
  DATE_RE = /\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|present|current|\d{4})\b/i
  COMPANY_RE = /\b(inc\.?|llc|ltd\.?|corp\.?|co\.?|gmbh|plc|remote|usa|uk|canada|nigeria|freelance)\b|\(.+\)/i
  TITLE_RE = /\b(engineer|developer|manager|director|analyst|designer|specialist|coordinator|consultant|lead|senior|junior|intern|associate|architect|administrator|officer|executive|president|vp|head\s+of|trainer|annotator|scientist|researcher|editor|writer|strategist|recruiter|qa|tester|devops|sre|cto|ceo|cfo)\b/i
  DEGREE_RE = /\b(bachelor|master|mba|ph\.?d|b\.?s\.?c?|m\.?s\.?c?|b\.?a\.?|m\.?a\.?|associate|diploma|certificate|degree|bsc|msc)\b/i
  SCHOOL_RE = /\b(university|college|institute|school|academy|polytechnic|microverse|bootcamp)\b/i

  def initialize(content)
    @content = content.to_s.strip
    # Strip any remaining code fences
    @content = @content.sub(/\A\s*```\w*\s*\n?/, "").sub(/\n?\s*```\s*\z/, "").strip
  end

  def parse
    return [] if @content.blank?

    raw_sections = split_into_sections
    structured = build_structured_sections(raw_sections)

    if structured.empty?
      structured << {
        section_type: "summary",
        content: { "text" => @content.lines.first(5).join.strip },
        position: 0
      }
    end

    structured
  end

  private

  # ==================== SECTION SPLITTING ====================

  def split_into_sections
    lines = @content.lines.map(&:rstrip)
    sections = []
    current_type = nil
    current_lines = []

    lines.each do |line|
      detected = detect_section_type(line)
      if detected
        if current_type.nil? && current_lines.any?
          sections << { type: "header", lines: current_lines.dup }
        elsif current_type
          sections << { type: current_type, lines: current_lines.dup }
        end
        current_type = detected
        current_lines = []
      else
        current_lines << line
      end
    end

    if current_type && current_lines.any?
      sections << { type: current_type, lines: current_lines.dup }
    elsif current_type.nil? && current_lines.any?
      sections << { type: "header", lines: current_lines.dup }
    end

    sections
  end

  def detect_section_type(line)
    stripped = line.strip
    return nil if stripped.blank?
    return nil if stripped.length > 50

    SECTION_PATTERNS.each do |type, pattern|
      return type if stripped.match?(pattern)
    end

    nil
  end

  # ==================== STRUCTURED BUILDING ====================

  def build_structured_sections(raw_sections)
    result = []
    position = 0

    raw_sections.each do |section|
      next if section[:type] == "header"

      content = build_content(section[:type], section[:lines])
      next if content_empty?(section[:type], content)

      result << { section_type: section[:type], content: content, position: position }
      position += 1
    end

    result
  end

  def build_content(type, lines)
    case type
    when "summary"
      { "text" => lines.map(&:strip).reject(&:blank?).join(" ") }
    when "experience"
      { "entries" => parse_experience_entries(lines) }
    when "education"
      { "entries" => parse_education_entries(lines) }
    when "skills"
      { "items" => parse_skill_items(lines) }
    when "projects"
      { "entries" => parse_project_entries(lines) }
    when "certifications", "awards", "languages"
      { "items" => parse_list_items(lines) }
    else
      { "text" => lines.map(&:strip).reject(&:blank?).join("\n") }
    end
  end

  # ==================== EXPERIENCE PARSING ====================
  #
  # Handles both formats:
  #   Format A: Company → Title → Dates → Bullets
  #   Format B: Title → Company | Dates → Bullets
  #
  # Strategy: split into "blocks" at transitions from bullets back to
  # non-bullet lines, then classify each block's header lines.

  def parse_experience_entries(lines)
    blocks = split_into_blocks(lines)

    entries = blocks.filter_map do |block|
      entry = classify_experience_block(block[:header], block[:bullets])
      entry if entry["title"].present? || entry["company"].present?
    end

    return entries if entries.any?

    # Fallback: treat all non-blank lines as a single summary
    text = lines.map(&:strip).reject(&:blank?)
    [ { "title" => text.first.to_s, "company" => "", "dates" => "", "bullets" => text.drop(1) } ]
  end

  def split_into_blocks(lines)
    blocks = []
    current_header = []
    current_bullets = []
    in_bullets = false

    lines.each do |line|
      stripped = line.strip
      next if stripped.blank?

      if bullet?(stripped)
        in_bullets = true
        current_bullets << strip_bullet(stripped)
      else
        # Non-bullet line after bullet lines → new block
        if in_bullets
          blocks << { header: current_header, bullets: current_bullets }
          current_header = [ stripped ]
          current_bullets = []
          in_bullets = false
        else
          current_header << stripped
        end
      end
    end

    blocks << { header: current_header, bullets: current_bullets } if current_header.any? || current_bullets.any?
    blocks
  end

  def classify_experience_block(header_lines, bullets)
    entry = { "title" => "", "company" => "", "dates" => "", "bullets" => bullets }

    date_line = nil
    title_line = nil
    company_line = nil
    remaining = []

    header_lines.each do |line|
      if date_line.nil? && pure_date_line?(line)
        date_line = line
      elsif title_line.nil? && looks_like_title?(line)
        title_line = line
      elsif company_line.nil? && looks_like_company?(line)
        company_line = line
      else
        remaining << line
      end
    end

    # If we have a date line that contains company info (e.g., "Company | Jan 2020 - Present")
    if date_line
      parts = date_line.split(/\s*[\|–—]\s*/)
      if parts.length >= 2
        date_parts = parts.select { |p| p.match?(DATE_RE) }
        non_date_parts = parts.reject { |p| p.match?(DATE_RE) }
        entry["dates"] = date_parts.join(" – ").strip
        if company_line.nil? && non_date_parts.any?
          company_line = non_date_parts.first.strip
        end
      else
        entry["dates"] = date_line.strip
      end
    end

    # Assign title and company from what we found
    entry["title"] = title_line.to_s.strip
    entry["company"] = company_line.to_s.strip

    # If only one header line was found and nothing classified, use heuristics
    if entry["title"].blank? && entry["company"].blank? && remaining.any?
      entry["title"] = remaining.shift.to_s.strip
    end
    if entry["company"].blank? && remaining.any?
      entry["company"] = remaining.shift.to_s.strip
    end
    if entry["dates"].blank? && remaining.any?
      date_candidate = remaining.find { |l| l.match?(DATE_RE) }
      if date_candidate
        entry["dates"] = date_candidate.strip
        remaining.delete(date_candidate)
      end
    end

    # Any remaining non-classified header lines → add to bullets
    remaining.each { |l| entry["bullets"].unshift(l.strip) } if remaining.any?

    entry
  end

  def looks_like_title?(text)
    return false if text.length > 80
    return false if bullet?(text)
    text.match?(TITLE_RE) && !text.match?(COMPANY_RE)
  end

  def looks_like_company?(text)
    return false if text.length > 100
    return false if bullet?(text)
    return false if pure_date_line?(text)
    # Company lines often have location info, "Inc", "LLC", "(Remote)", etc.
    text.match?(COMPANY_RE)
  end

  def pure_date_line?(text)
    # A line that is primarily a date (not a long sentence)
    return false if text.length > 60
    text.match?(DATE_RE)
  end

  # ==================== EDUCATION PARSING ====================

  def parse_education_entries(lines)
    # Split into groups at blank lines first, then at bullet transitions
    groups = split_at_blank_lines(lines)

    entries = groups.filter_map do |group_lines|
      block = split_into_blocks(group_lines)
      if block.any?
        classify_education_block(block.first[:header], block.flat_map { |b| b[:bullets] })
      else
        nil
      end
    end

    return entries if entries.any?

    # Fallback: try the whole thing as one block
    blocks = split_into_blocks(lines)
    entries = blocks.filter_map { |b| classify_education_block(b[:header], b[:bullets]) }
    return entries if entries.any?

    text = lines.map(&:strip).reject(&:blank?)
    [ { "degree" => text.first.to_s, "school" => "", "dates" => "", "details" => text.drop(1).join(", ") } ]
  end

  def split_at_blank_lines(lines)
    groups = []
    current = []

    lines.each do |line|
      if line.strip.blank?
        groups << current.dup if current.any?
        current = []
      else
        current << line
      end
    end

    groups << current if current.any?
    groups
  end

  def classify_education_block(header_lines, bullets)
    entry = { "degree" => "", "school" => "", "dates" => "", "details" => "" }

    header_lines.each do |line|
      stripped = line.strip
      if entry["dates"].blank? && pure_date_line?(stripped)
        # Could be "School | Dates" combined
        parts = stripped.split(/\s*[\|–—]\s*/)
        if parts.length >= 2
          date_parts = parts.select { |p| p.match?(DATE_RE) }
          non_date_parts = parts.reject { |p| p.match?(DATE_RE) }
          entry["dates"] = date_parts.join(" – ").strip
          if entry["school"].blank? && non_date_parts.any?
            entry["school"] = non_date_parts.first.strip
          end
        else
          entry["dates"] = stripped
        end
      elsif entry["degree"].blank? && stripped.match?(DEGREE_RE)
        entry["degree"] = stripped
      elsif entry["school"].blank? && (stripped.match?(SCHOOL_RE) || entry["degree"].present?)
        entry["school"] = stripped
      elsif entry["degree"].blank?
        entry["degree"] = stripped
      else
        entry["details"] = [ entry["details"], stripped ].reject(&:blank?).join("; ")
      end
    end

    # Add bullet items as details
    if bullets.any?
      entry["details"] = [ entry["details"], bullets.join("; ") ].reject(&:blank?).join("; ")
    end

    return nil if entry["degree"].blank? && entry["school"].blank?
    entry
  end

  # ==================== SKILLS PARSING ====================

  def parse_skill_items(lines)
    text = lines.map(&:strip).reject(&:blank?).join(", ")
    # Strip bullet prefixes, then split
    text.gsub!(BULLET_RE, "")
    text.gsub!(/^-\s+/, "")
    items = text.split(/\s*[,;|•\u2022]\s*/)
                .map { |i| i.strip.sub(/\A-\s*/, "") }
                .reject(&:blank?)
                .uniq
    items
  end

  # ==================== PROJECTS PARSING ====================

  def parse_project_entries(lines)
    entries = []

    lines.each do |line|
      stripped = line.strip
      next if stripped.blank?

      cleaned = strip_bullet(stripped)

      # "ProjectName - Description" on one line
      if cleaned.include?(" - ")
        name, desc = cleaned.split(" - ", 2)
        entries << { "name" => name.strip, "description" => desc.to_s.strip }
      elsif !bullet?(stripped) && cleaned.length < 80
        entries << { "name" => cleaned, "description" => "" }
      elsif entries.any?
        entries.last["description"] = [ entries.last["description"], cleaned ].reject(&:blank?).join(" ")
      end
    end

    entries.presence || [ { "name" => lines.map(&:strip).reject(&:blank?).first.to_s, "description" => "" } ]
  end

  # ==================== LIST PARSING ====================

  def parse_list_items(lines)
    lines.map(&:strip)
         .reject(&:blank?)
         .map { |l| strip_bullet(l) }
         .reject { |l| l.match?(/\A```/) } # Remove stray code fences
         .reject { |l| l.match?(/\A(location|address)\z/i) } # Remove stray "LOCATION" headers
  end

  # ==================== UTILITIES ====================

  def bullet?(text)
    text.match?(BULLET_RE) || text.match?(/\A-\s+/)
  end

  def strip_bullet(text)
    text.sub(BULLET_RE, "").sub(/\A-\s+/, "")
  end

  def content_empty?(type, content)
    case type
    when "summary"
      content["text"].blank?
    when "experience", "education", "projects"
      entries = content["entries"]
      entries.blank? || entries.all? { |e| e.values.all? { |v| v.is_a?(Array) ? v.empty? : v.blank? } }
    when "skills", "certifications", "awards", "languages"
      content["items"].blank?
    else
      true
    end
  end
end
