class Article < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  CATEGORIES = %w[resume_tips cover_letter_guide interview_prep ats_guide career_advice].freeze

  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true

  scope :published, -> { where(published: true).where('published_at <= ?', Time.current) }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }

  def category_label
    category&.humanize&.titleize || 'General'
  end

  def category_color
    case category
    when 'resume_tips' then 'blue'
    when 'cover_letter_guide' then 'purple'
    when 'interview_prep' then 'green'
    when 'ats_guide' then 'yellow'
    when 'career_advice' then 'red'
    else 'gray'
    end
  end

  def tags_list
    tags.is_a?(Array) ? tags : []
  end

  def related_articles(limit: 3)
    Article.published.where(category: category).where.not(id: id).recent.limit(limit)
  end
end
