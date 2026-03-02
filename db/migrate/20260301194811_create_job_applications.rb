class CreateJobApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :job_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, foreign_key: true
      t.references :cover_letter, foreign_key: true
      t.string :company_name, null: false
      t.string :role, null: false
      t.string :url
      t.string :status, default: 'applied'
      t.date :applied_at
      t.date :follow_up_at
      t.text :notes
      t.string :salary_offered
      t.string :location
      t.boolean :remote, default: false
      t.string :contact_name
      t.string :contact_email
      t.timestamps
    end
    add_index :job_applications, [:user_id, :status]
  end
end
