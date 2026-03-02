class LinkedinOptimization < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  enum status: {
    draft: "draft",
    processing: "processing",
    optimized: "optimized",
    failed: "failed"
  }

  validates :target_role, presence: true
  validates :status, inclusion: { in: statuses.keys }

  scope :recent, -> { order(created_at: :desc) }

  def suggestions_list
    suggestions.is_a?(Array) ? suggestions : []
  end

  def has_optimized_content?
    optimized_headline.present? || optimized_about.present? || optimized_experience.present?
  end
end
