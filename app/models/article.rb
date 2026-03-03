class Article < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  CATEGORIES = %w[resume_tips cover_letter_guide interview_prep ats_guide career_advice].freeze

  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true

  scope :published, -> { where(published: true).where("published_at <= ?", Time.current) }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }

  def category_label
    category&.humanize&.titleize || "General"
  end

  def category_color
    case category
    when "resume_tips" then "blue"
    when "cover_letter_guide" then "purple"
    when "interview_prep" then "green"
    when "ats_guide" then "yellow"
    when "career_advice" then "red"
    else "gray"
    end
  end

  # Returns full static Tailwind classes to avoid JIT purge issues
  def category_badge_classes
    case category
    when "resume_tips"         then "bg-blue-100 text-blue-700"
    when "cover_letter_guide"  then "bg-purple-100 text-purple-700"
    when "interview_prep"      then "bg-green-100 text-green-700"
    when "ats_guide"           then "bg-yellow-100 text-yellow-700"
    when "career_advice"       then "bg-red-100 text-red-700"
    else                            "bg-gray-100 text-gray-700"
    end
  end

  def category_gradient_classes
    case category
    when "resume_tips"         then "from-blue-100 to-blue-200"
    when "cover_letter_guide"  then "from-purple-100 to-purple-200"
    when "interview_prep"      then "from-green-100 to-green-200"
    when "ats_guide"           then "from-yellow-100 to-yellow-200"
    when "career_advice"       then "from-red-100 to-red-200"
    else                            "from-gray-100 to-gray-200"
    end
  end

  def category_icon_class
    case category
    when "resume_tips"         then "text-blue-400"
    when "cover_letter_guide"  then "text-purple-400"
    when "interview_prep"      then "text-green-400"
    when "ats_guide"           then "text-yellow-400"
    when "career_advice"       then "text-red-400"
    else                            "text-gray-400"
    end
  end

  def tags_list
    tags.is_a?(Array) ? tags : []
  end

  def related_articles(limit: 3)
    Article.published.where(category: category).where.not(id: id).recent.limit(limit)
  end
end
