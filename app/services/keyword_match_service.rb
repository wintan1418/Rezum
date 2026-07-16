class KeywordMatchService
  # Deterministically matches job-description keywords against resume text.
  # Produces a reproducible match rate and a matched/missing gap table,
  # replacing LLM guesswork for the keyword component of ATS scoring.

  # Hard requirements dominate real ATS/recruiter searches, so they carry
  # the most weight; soft skills the least.
  CATEGORY_WEIGHTS = {
    "required_hard_skills" => 3,
    "preferred_hard_skills" => 2,
    "domain_expertise" => 2,
    "certifications" => 2,
    "soft_skills" => 1
  }.freeze
  DEFAULT_WEIGHT = 1

  # keywords: array of { term:, category: } hashes (string or symbol keys)
  def initialize(resume_text:, keywords:)
    @resume_text = resume_text.to_s
    @keywords = Array(keywords)
  end

  def match
    matched = []
    missing = []

    @keywords.each do |keyword|
      term = (keyword[:term] || keyword["term"]).to_s.strip
      next if term.empty?

      category = (keyword[:category] || keyword["category"]).to_s
      count = variants_for(term).map { |v| occurrence_count(v) }.max.to_i
      entry = { term: term, category: category, count: count }

      count.positive? ? matched << entry : missing << entry
    end

    {
      matched: matched,
      missing: missing,
      match_rate: weighted_rate(matched, missing)
    }
  end

  private

  # "Search Engine Optimization (SEO)" matches as either the full term or
  # the acronym; either counts as covered.
  def variants_for(term)
    if (m = term.match(/\A(.+?)\s*\(([^)]+)\)\z/))
      [ m[1].strip, m[2].strip ]
    else
      [ term ]
    end
  end

  # Word-boundary matching that survives terms like "C++", ".NET", "C#":
  # neighbours must not be alphanumeric, but the term itself may contain
  # any characters.
  def occurrence_count(term)
    pattern = /(?<![[:alnum:]])#{Regexp.escape(term)}(?![[:alnum:]])/i
    @resume_text.scan(pattern).size
  end

  def weighted_rate(matched, missing)
    total = (matched + missing).sum { |e| weight_for(e[:category]) }
    return 0 if total.zero?

    covered = matched.sum { |e| weight_for(e[:category]) }
    ((covered.to_f / total) * 100).round
  end

  def weight_for(category)
    CATEGORY_WEIGHTS.fetch(category, DEFAULT_WEIGHT)
  end
end
