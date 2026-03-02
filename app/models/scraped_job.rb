class ScrapedJob < ApplicationRecord
  belongs_to :user

  validates :company_name, presence: true
  validates :role, presence: true
  validates :status, inclusion: { in: %w[new saved applied hidden archived] }
  validates :match_score, numericality: { in: 0..100 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: %w[new saved]) }
  scope :high_match, -> { where('match_score >= ?', 70).order(match_score: :desc) }
  scope :not_hidden, -> { where.not(status: %w[hidden archived]) }

  def status_color
    case status
    when 'new' then 'blue'
    when 'saved' then 'yellow'
    when 'applied' then 'green'
    when 'hidden' then 'gray'
    when 'archived' then 'gray'
    else 'gray'
    end
  end

  def match_color
    case match_score
    when 80..100 then 'green'
    when 60..79 then 'yellow'
    when 0..59 then 'red'
    else 'gray'
    end
  end

  def tags_list
    tags.is_a?(Array) ? tags : []
  end

  def remote_label
    remote? ? 'Remote' : (location.presence || 'On-site')
  end

  def short_description
    return '' if description.blank?
    description.truncate(200)
  end
end
