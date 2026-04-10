class Lead < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :from_ats_checker, -> { where(source: "ats_checker") }
  scope :recent, -> { order(created_at: :desc) }
end
