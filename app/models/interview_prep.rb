class InterviewPrep < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true
  belongs_to :job_application, optional: true

  enum status: {
    pending: 'pending',
    generating: 'generating',
    generated: 'generated',
    failed: 'failed'
  }

  validates :target_role, presence: true
  validates :status, inclusion: { in: statuses.keys }

  scope :recent, -> { order(created_at: :desc) }

  def questions_list
    questions.is_a?(Array) ? questions : []
  end

  def company_questions_list
    company_questions.is_a?(Array) ? company_questions : []
  end
end
