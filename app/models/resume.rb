class Resume < ApplicationRecord
  belongs_to :user
  has_many :cover_letters, dependent: :destroy
  has_many :job_applications
  has_many :resume_sections, -> { order(position: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :resume_sections

  # File attachments
  has_one_attached :file do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [ 200, 300 ]
  end

  before_save :strip_code_fences

  validates :original_content, presence: true, length: { minimum: 100 }
  validates :target_role, presence: true, length: { minimum: 2 }
  validates :status, inclusion: { in: %w[draft processing optimized failed] }
  validates :provider, inclusion: { in: %w[openai anthropic google] }, allow_blank: true
  validates :ats_score, numericality: { in: 0..100 }, allow_nil: true

  enum status: {
    draft: "draft",
    processing: "processing",
    optimized: "optimized",
    failed: "failed"
  }

  enum provider: {
    openai: "openai",
    anthropic: "anthropic",
    google: "google"
  }, _prefix: true

  scope :optimized, -> { where(status: "optimized") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_role, ->(role) { where(target_role: role) }

  def optimized?
    status == "optimized" && optimized_content.present?
  end

  def processing?
    status == "processing"
  end

  def keywords_array
    keywords&.split(",")&.map(&:strip) || []
  end

  def keywords_array=(array)
    self.keywords = array.join(", ") if array.present?
  end

  # keyword_match_data: { "keywords" => [{"term","category"}], "matched" => [...],
  # "missing" => [...], "match_rate" => 72, "computed_at" => iso8601 }
  def keyword_match
    keyword_match_data.presence || {}
  end

  def keyword_match_rate
    keyword_match["match_rate"]
  end

  def matched_keywords
    Array(keyword_match["matched"])
  end

  def missing_keywords
    Array(keyword_match["missing"])
  end

  def keyword_match_computed?
    keyword_match["match_rate"].present?
  end

  # Recomputes the deterministic keyword match against current optimized
  # content, reusing the keywords extracted during ATS analysis.
  def recompute_keyword_match!
    terms = Array(keyword_match["keywords"])
    return if terms.empty? || optimized_content.blank?

    result = KeywordMatchService.new(resume_text: optimized_content, keywords: terms).match
    update!(keyword_match_data: keyword_match.merge(
      "matched" => result[:matched].map { |e| e.transform_keys(&:to_s) },
      "missing" => result[:missing].map { |e| e.transform_keys(&:to_s) },
      "match_rate" => result[:match_rate],
      "computed_at" => Time.current.iso8601
    ))
    result
  end

  # Re-parses optimized_content into structured sections (used after
  # optimization and after Tailoring Studio edits). Keeps existing sections
  # when parsing produces nothing usable.
  def rebuild_sections_from_optimized!
    parsed = ResumeContentParserService.new(optimized_content).parse

    if parsed.blank? || (parsed.length == 1 && parsed.first[:section_type] == "summary" && parsed.first[:content]["text"]&.length.to_i < 50)
      Rails.logger.warn "Section parsing produced insufficient results for resume #{id}, keeping existing sections"
      return false
    end

    resume_sections.destroy_all
    parsed.each do |section_data|
      resume_sections.create!(
        section_type: section_data[:section_type],
        content: section_data[:content],
        position: section_data[:position],
        visible: true
      )
    end
    true
  rescue StandardError => e
    Rails.logger.warn "Rebuilding sections failed for resume #{id}: #{e.message}"
    false
  end

  def ats_score_color
    return "gray" if ats_score.blank?

    case ats_score
    when 0..40
      "red"
    when 41..70
      "yellow"
    when 71..100
      "green"
    else
      "gray"
    end
  end

  private

  def strip_code_fences
    [ original_content, optimized_content ].each_with_index do |content, i|
      next if content.blank?

      cleaned = content
        .sub(/\A\s*```(?:plaintext|text|markdown|plain|ruby|json)?\s*\n?/, "")
        .sub(/\n?\s*```\s*\z/, "")
        .strip

      if i == 0
        self.original_content = cleaned
      else
        self.optimized_content = cleaned
      end
    end
  end
end
