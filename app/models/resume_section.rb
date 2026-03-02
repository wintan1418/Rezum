class ResumeSection < ApplicationRecord
  belongs_to :resume

  SECTION_TYPES = %w[summary experience education skills certifications projects languages awards].freeze

  validates :section_type, presence: true, inclusion: { in: SECTION_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc) }
  scope :visible, -> { where(visible: true) }

  def content_data
    content.is_a?(Hash) ? content : {}
  end

  def section_label
    section_type.humanize.titleize
  end

  def section_icon
    case section_type
    when 'summary' then 'user'
    when 'experience' then 'briefcase'
    when 'education' then 'academic-cap'
    when 'skills' then 'lightning-bolt'
    when 'certifications' then 'badge-check'
    when 'projects' then 'code'
    when 'languages' then 'globe'
    when 'awards' then 'star'
    else 'document'
    end
  end
end
