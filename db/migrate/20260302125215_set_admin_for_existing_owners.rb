class SetAdminForExistingOwners < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE users SET admin = true WHERE LOWER(email) IN ('wintan1418@gmail.com')"
  end

  def down
    execute "UPDATE users SET admin = false WHERE LOWER(email) IN ('wintan1418@gmail.com')"
  end
end
