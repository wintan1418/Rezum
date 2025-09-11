class CreateResumes < ActiveRecord::Migration[7.2]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.text :original_content
      t.text :optimized_content
      t.text :job_description
      t.string :target_role
      t.string :industry
      t.string :experience_level
      t.integer :ats_score
      t.text :keywords
      t.string :status
      t.string :provider

      t.timestamps
    end
  end
end
