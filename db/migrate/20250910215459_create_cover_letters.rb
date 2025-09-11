class CreateCoverLetters < ActiveRecord::Migration[7.2]
  def change
    create_table :cover_letters do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, null: false, foreign_key: true
      t.string :company_name
      t.string :hiring_manager_name
      t.string :target_role
      t.string :tone
      t.string :length
      t.text :content
      t.text :job_description
      t.string :status
      t.string :provider

      t.timestamps
    end
  end
end
