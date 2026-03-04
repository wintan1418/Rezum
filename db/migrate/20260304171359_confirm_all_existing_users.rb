class ConfirmAllExistingUsers < ActiveRecord::Migration[7.2]
  def up
    # Confirm all existing users so they don't get locked out
    # when we enable mandatory email confirmation
    execute <<-SQL
      UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL
    SQL
  end

  def down
    # No-op: we don't want to un-confirm users
  end
end
