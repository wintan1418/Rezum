class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject
      t.string :status, default: "open"
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
