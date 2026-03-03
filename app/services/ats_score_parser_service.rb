class AtsScoreParserService
  def initialize(raw_response)
    @raw = raw_response.to_s
  end

  def parse
    {
      overall_score: extract_score("OVERALL ATS SCORE"),
      format_score: extract_score("FORMAT SCORE"),
      content_score: extract_score("CONTENT SCORE"),
      strengths: extract_list("STRENGTHS"),
      issues: extract_list("ISSUES"),
      improvements: extract_numbered_list("IMPROVEMENTS")
    }
  end

  private

  def extract_score(label)
    match = @raw.match(/#{Regexp.escape(label)}:\s*(\d+)/i)
    match ? match[1].to_i.clamp(0, 100) : 0
  end

  def extract_list(label)
    match = @raw.match(/#{Regexp.escape(label)}:\s*(.+?)(?:\n[A-Z]|\n\d+\.|\z)/mi)
    return [] unless match

    match[1].strip.split(/,\s*/).map(&:strip).reject(&:blank?)
  end

  def extract_numbered_list(label)
    section = @raw.split(/#{Regexp.escape(label)}:?\s*/i, 2).last
    return [] unless section

    items = section.scan(/^\d+\.\s*(.+)$/).flatten.map(&:strip).reject(&:blank?)
    items.first(7)
  end
end
