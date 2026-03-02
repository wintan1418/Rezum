class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true

  after_create_commit :broadcast_message
  after_create_commit :update_conversation_timestamp

  scope :recent, -> { order(created_at: :asc) }

  private

  def broadcast_message
    broadcast_append_to(
      "conversation_#{conversation_id}",
      target: "messages_#{conversation_id}",
      partial: "chat/message",
      locals: { message: self }
    )
  end

  def update_conversation_timestamp
    conversation.update(last_message_at: created_at)
  end
end
