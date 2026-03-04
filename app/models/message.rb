class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true

  after_create_commit :update_conversation_timestamp

  scope :recent, -> { order(created_at: :asc) }

  # Broadcast to conversation channel — must be called from controller context
  # where current_user is available (not from model callback, which lacks Warden)
  def broadcast_to_conversation(viewing_user:)
    broadcast_append_to(
      "conversation_#{conversation_id}",
      target: "messages_#{conversation_id}",
      partial: "chat/message",
      locals: { message: self, viewing_user: viewing_user }
    )
  end

  private

  def update_conversation_timestamp
    conversation.update(last_message_at: created_at)
  end
end
