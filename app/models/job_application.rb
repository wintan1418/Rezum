class JobApplication < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true
  belongs_to :cover_letter, optional: true

  enum status: {
    wishlist: "wishlist",
    applied: "applied",
    phone_screen: "phone_screen",
    interview: "interview",
    offer: "offer",
    rejected: "rejected",
    withdrawn: "withdrawn"
  }

  validates :company_name, presence: true
  validates :role, presence: true
  validates :status, inclusion: { in: statuses.keys }

  scope :recent, -> { order(updated_at: :desc) }
  scope :active, -> { where(status: %w[applied phone_screen interview]) }
  scope :by_status, ->(s) { where(status: s) }
  scope :needs_follow_up, -> { where("follow_up_at <= ?", Date.current).where.not(status: %w[rejected withdrawn offer]) }

  def status_color
    case status
    when "wishlist" then "gray"
    when "applied" then "blue"
    when "phone_screen" then "yellow"
    when "interview" then "purple"
    when "offer" then "green"
    when "rejected" then "red"
    when "withdrawn" then "gray"
    else "gray"
    end
  end

  def status_emoji
    case status
    when "wishlist" then "&#9734;"
    when "applied" then "&#10003;"
    when "phone_screen" then "&#9742;"
    when "interview" then "&#128172;"
    when "offer" then "&#127881;"
    when "rejected" then "&#10005;"
    when "withdrawn" then "&#8617;"
    else ""
    end
  end

  def days_since_applied
    return nil unless applied_at
    (Date.current - applied_at).to_i
  end

  def needs_follow_up?
    follow_up_at.present? && follow_up_at <= Date.current && !%w[rejected withdrawn offer].include?(status)
  end
end
