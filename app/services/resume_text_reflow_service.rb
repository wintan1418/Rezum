# Repairs layout damage from text extraction. PDF (and some DOCX/TXT)
# extraction emits one line per visual line, so paragraphs and bullets
# arrive broken mid-sentence, and two-column skill grids are read across
# the page as "• A • B". This service:
#
#   * joins wrapped continuation lines back onto their sentence/bullet
#   * splits lines that carry several inline bullets into one per line
#   * normalises bullet markers to "- " and collapses blank-line runs
#
# It is deliberately conservative: short lines (names, titles, dates,
# section headers) are never joined, so Title / Company / Dates stacks and
# headers survive untouched. Running it twice is a no-op.
class ResumeTextReflowService
  BULLET_MARKERS = "•‣◦⁃∙▪●■–—*-".freeze
  BULLET_RE = /\A[#{Regexp.escape(BULLET_MARKERS)}]\s+/
  INLINE_BULLET_RE = /\s+[•‣◦⁃∙▪●■]\s+/
  SENTENCE_END_RE = /[.:;!?)\]"”»]\z/
  DATE_WORD_RE = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{4}\b|\b(19|20)\d{2}\b|\b(present|current)\b/i
  CONTACT_RE = /@|\+\d|\(\d{3}\)|\bhttps?:|\blinkedin\.com|\bgithub\.com|\d{3}[-.\s]\d{3}[-.\s]\d{4}/i

  # Lines at or above this width are treated as "full width" and therefore
  # plausibly wrapped by the extractor.
  WRAP_WIDTH = 70

  def initialize(text)
    @text = text.to_s
  end

  def reflow
    lines = @text.gsub(/\r\n?/, "\n").split("\n").map { |l| l.gsub(/[ \t]+/, " ").strip }
    lines = lines.flat_map { |l| split_inline_bullets(l) }
    lines = join_wrapped_lines(lines)
    lines = lines.map { |l| normalise_bullet(l) }
    collapse_blank_runs(lines).join("\n").strip
  end

  private

  # "• A • B • C" (two/three-column grids read across) → three lines.
  # Only triggers on lines that start with a bullet and contain at least
  # one more marker surrounded by spaces, so prose using "•" inline is safe.
  def split_inline_bullets(line)
    return [ line ] unless line.match?(BULLET_RE) && line.match?(INLINE_BULLET_RE)

    marker = line[0]
    line.sub(BULLET_RE, "").split(INLINE_BULLET_RE).map(&:strip).reject(&:blank?).map { |part| "#{marker} #{part}" }
  end

  def join_wrapped_lines(lines)
    out = []
    lines.each do |line|
      if out.any? && continuation?(out.last, line)
        out[-1] = "#{out.last} #{line}"
      else
        out << line
      end
    end
    out
  end

  # Is `line` the wrapped tail of `prev`?
  def continuation?(prev, line)
    return false if prev.blank? || line.blank?
    return false if line.match?(BULLET_RE)
    return false if standalone?(line)
    return false if standalone?(prev) && !prev.match?(BULLET_RE)

    # Strong signal: the extractor broke mid-sentence, next line starts lowercase
    return true if line.match?(/\A[[:lower:]]/) && !prev.match?(SENTENCE_END_RE)

    # Weaker signal: the previous line is full width and does not finish a sentence
    prev.length >= WRAP_WIDTH && !prev.match?(SENTENCE_END_RE) && !line.match?(CONTACT_RE)
  end

  # Lines that must stay on their own: headers, names, titles, dates,
  # contact details, pipe-delimited role lines.
  def standalone?(line)
    return true if section_header?(line)
    return true if line.length <= 40 && line.match?(DATE_WORD_RE)
    return true if line.include?(" | ")
    return true if line.match?(CONTACT_RE)
    return true if line.length <= 60 && line == line.upcase && line.match?(/[[:alpha:]]/)
    return true if line.match?(/:\z/)
    false
  end

  def section_header?(line)
    ResumeContentParserService.section_header?(line)
  end

  def normalise_bullet(line)
    line.sub(BULLET_RE, "- ")
  end

  def collapse_blank_runs(lines)
    result = []
    lines.each do |line|
      next if line.blank? && result.last.to_s.blank?
      result << line
    end
    result
  end
end
