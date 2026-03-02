class CreateScrapedJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :scraped_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :role, null: false
      t.string :location
      t.string :salary_range
      t.string :url
      t.text :description
      t.string :source, default: 'google_jobs'
      t.string :job_type
      t.boolean :remote, default: false
      t.integer :match_score, default: 0
      t.string :status, default: 'new'
      t.datetime :applied_at
      t.datetime :expires_at
      t.json :tags, default: []
      t.text :notes
      t.string :external_id

      t.timestamps
    end

    add_index :scraped_jobs, [:user_id, :status]
    add_index :scraped_jobs, [:user_id, :match_score]
    add_index :scraped_jobs, :external_id
  end
end
