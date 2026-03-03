class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :subscriptions, [:status, :user_id], name: "index_subscriptions_on_status_and_user_id"
    add_index :payments, [:user_id, :status], name: "index_payments_on_user_id_and_status"
    add_index :messages, [:conversation_id, :read], name: "index_messages_on_conversation_id_and_read"
    add_index :resumes, [:user_id, :status], name: "index_resumes_on_user_id_and_status"
    add_index :cover_letters, [:user_id, :status], name: "index_cover_letters_on_user_id_and_status"
    add_index :conversations, :status, name: "index_conversations_on_status"
    add_index :articles, [:published, :published_at], name: "index_articles_on_published_and_published_at"
  end
end
