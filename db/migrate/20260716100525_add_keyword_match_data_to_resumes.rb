class AddKeywordMatchDataToResumes < ActiveRecord::Migration[7.2]
  def change
    add_column :resumes, :keyword_match_data, :jsonb
  end
end
