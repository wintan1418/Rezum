class AddEmailTrackingToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :last_email_sent_at, :datetime
    add_column :users, :email_sequence_stage, :integer, default: 0
    add_column :users, :unsubscribed_at, :datetime
  end
end
