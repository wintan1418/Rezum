class PitchDeck < ApplicationRecord
  belongs_to :user
  has_many :slides, class_name: "PitchDeckSlide", dependent: :destroy

  validates :company_name, presence: true
  validates :status, inclusion: { in: %w[draft generating completed failed] }
  validates :template, inclusion: { in: %w[sequoia yc kawasaki] }
  validates :color_scheme, inclusion: { in: %w[professional bold minimal dark] }
  validates :stage, inclusion: { in: %w[pre-seed seed series-a series-b growth] }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(s) { where(status: s) }
  scope :completed, -> { where(status: "completed") }

  CREDITS_COST = 30

  SLIDE_TYPES = %w[
    cover problem solution why_now market product
    business_model traction competition team financials ask
  ].freeze

  def draft?
    status == "draft"
  end

  def generating?
    status == "generating"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def mark_generating!
    update!(status: "generating")
  end

  def mark_completed!
    update!(status: "completed", generated_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message)
  end

  def slide_for(type)
    slides.find_by(slide_type: type)
  end

  def ordered_slides
    slides.where(visible: true).order(:position)
  end

  def display_stage
    stage&.titleize&.gsub("-", " ") || "Not specified"
  end
end
