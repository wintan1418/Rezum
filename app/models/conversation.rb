class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  enum :status, { open: "open", closed: "closed" }

  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }

  def last_message
    messages.order(created_at: :desc).first
  end

  def unread_count_for(user)
    messages.where.not(user: user).where(read: false).count
  end
end
