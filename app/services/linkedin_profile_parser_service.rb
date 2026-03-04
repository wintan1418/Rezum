class LinkedinProfileParserService
  attr_reader :text

  def initialize(text)
    @text = text.to_s.strip
  end

  def parse
    sections = []
    position = 0

    # Extract name from first non-empty line
    name = extract_name
    headline = extract_headline

    # Summary / About
    about = extract_section("About", "Experience")
    if about.present?
      sections << { section_type: "summary", content: { "text" => about.strip }, position: position }
      position += 1
    end

    # Experience
    experience_entries = extract_experience
    if experience_entries.any?
      sections << { section_type: "experience", content: { "entries" => experience_entries }, position: position }
      position += 1
    end

    # Education
    education_entries = extract_education
    if education_entries.any?
      sections << { section_type: "education", content: { "entries" => education_entries }, position: position }
      position += 1
    end

    # Skills
    skills = extract_skills
    if skills.any?
      sections << { section_type: "skills", content: { "items" => skills }, position: position }
      position += 1
    end

    # Certifications
    certs = extract_list_section("Licenses & Certifications", "Certifications")
    if certs.any?
      sections << { section_type: "certifications", content: { "items" => certs }, position: position }
      position += 1
    end

    # Languages
    languages = extract_list_section("Languages")
    if languages.any?
      sections << { section_type: "languages", content: { "items" => languages }, position: position }
      position += 1
    end

    {
      name: name,
      headline: headline,
      sections: sections,
      raw_text: text
    }
  end

  private

  def lines
    @lines ||= text.lines.map(&:strip)
  end

  def extract_name
    # First non-empty line is usually the name
    lines.find(&:present?)
  end

  def extract_headline
    # Second non-empty line is usually the headline/title
    non_empty = lines.select(&:present?)
    non_empty[1] if non_empty.length > 1
  end

  def extract_section(start_header, *end_headers)
    all_headers = section_headers
    start_idx = find_header_index(start_header)
    return nil unless start_idx

    # Find end: next known section header
    content_lines = []
    (start_idx + 1...lines.length).each do |i|
      line = lines[i]
      break if all_headers.any? { |h| line.match?(/\A#{Regexp.escape(h)}\s*\z/i) } ||
               end_headers.any? { |h| line.match?(/\A#{Regexp.escape(h)}\s*\z/i) }
      content_lines << line
    end

    content_lines.reject(&:blank?).join("\n")
  end

  def extract_experience
    entries = []
    block = extract_block("Experience", "Education", "Skills", "Licenses", "Certifications", "Projects", "Languages", "Honors", "Awards", "Volunteer")
    return entries if block.blank?

    # Parse experience entries - LinkedIn format typically:
    # Title
    # Company · Full-time (or similar)
    # Date range · Duration
    # Location
    # Description bullets
    current_entry = nil

    block.lines.map(&:strip).each do |line|
      next if line.blank?

      # Detect date patterns like "Jan 2020 - Present" or "2018 - 2022"
      if line.match?(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{4})\b.*[-–]\s*(present|\d{4}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i)
        if current_entry
          current_entry["dates"] = line.split("·").first&.strip || line
        end
      elsif line.match?(/[·•]/) && !line.start_with?("•") && !line.start_with?("-")
        # Company line like "Google · Full-time"
        if current_entry && current_entry["company"].blank?
          current_entry["company"] = line.split("·").first&.strip || line
        end
      elsif line.start_with?("•") || line.start_with?("-") || line.start_with?("–")
        current_entry["bullets"] << line.sub(/\A[•\-–]\s*/, "").strip if current_entry
      elsif line.length > 3 && !line.match?(/^\d+ yr|^\d+ mo|^[A-Z][a-z]+,\s[A-Z]/)
        # Likely a new title - save previous and start new
        if current_entry && current_entry["title"].present?
          entries << current_entry
        end
        current_entry = { "title" => line, "company" => "", "dates" => "", "bullets" => [] }
      end
    end

    entries << current_entry if current_entry && current_entry["title"].present?
    entries
  end

  def extract_education
    entries = []
    block = extract_block("Education", "Skills", "Licenses", "Certifications", "Projects", "Languages", "Honors", "Awards", "Volunteer", "Experience")
    return entries if block.blank?

    current_entry = nil

    block.lines.map(&:strip).each do |line|
      next if line.blank?

      if line.match?(/\b(university|college|institute|school|academy|polytechnic)\b/i) ||
         (current_entry.nil? && line.length > 3)
        entries << current_entry if current_entry
        current_entry = { "degree" => "", "school" => line, "dates" => "", "details" => "" }
      elsif current_entry
        if line.match?(/\b\d{4}\b/)
          current_entry["dates"] = line.split("·").first&.strip || line
        elsif current_entry["degree"].blank?
          current_entry["degree"] = line.split("·").first&.strip || line
        else
          current_entry["details"] = [current_entry["details"], line].reject(&:blank?).join(". ")
        end
      end
    end

    entries << current_entry if current_entry
    entries
  end

  def extract_skills
    block = extract_block("Skills", "Languages", "Licenses", "Certifications", "Honors", "Awards", "Recommendations", "Education", "Experience")
    return [] if block.blank?

    block.lines
      .map(&:strip)
      .reject(&:blank?)
      .reject { |l| l.match?(/endorsed|endorsement|\d+ skill/i) }
      .map { |l| l.split("·").first&.strip }
      .compact
      .reject { |s| s.length > 60 }
      .first(30)
  end

  def extract_list_section(*headers)
    headers.each do |header|
      block = extract_block(header, *section_headers.reject { |h| h.casecmp?(header) })
      next if block.blank?

      return block.lines
        .map(&:strip)
        .reject(&:blank?)
        .reject { |l| l.match?(/issued|credential|expir/i) && l.length < 20 }
        .first(20)
    end
    []
  end

  def extract_block(*headers)
    start_header = headers.shift
    start_idx = find_header_index(start_header)
    return nil unless start_idx

    content_lines = []
    all_possible_ends = headers + section_headers

    (start_idx + 1...lines.length).each do |i|
      line = lines[i]
      break if all_possible_ends.any? { |h| line.match?(/\A#{Regexp.escape(h)}\s*\z/i) }
      content_lines << line
    end

    content_lines.join("\n")
  end

  def find_header_index(header)
    lines.index { |l| l.match?(/\A#{Regexp.escape(header)}\s*\z/i) }
  end

  def section_headers
    %w[About Experience Education Skills Projects Languages Certifications Awards Honors Volunteer Recommendations Publications Courses Interests]
      .concat(["Licenses & Certifications", "Honors & Awards"])
  end
end
