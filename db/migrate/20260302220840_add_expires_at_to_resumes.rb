class AddExpiresAtToResumes < ActiveRecord::Migration[7.2]
  def change
    add_column :resumes, :expires_at, :datetime
  end
end
