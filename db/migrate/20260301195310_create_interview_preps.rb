class CreateInterviewPreps < ActiveRecord::Migration[7.2]
  def change
    create_table :interview_preps do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, foreign_key: true
      t.references :job_application, foreign_key: true
      t.text :job_description
      t.string :company_name
      t.string :target_role
      t.json :questions, default: []
      t.json :company_questions, default: []
      t.string :status, default: 'pending'
      t.string :provider
      t.timestamps
    end
  end
end
