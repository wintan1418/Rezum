class CreateJobScraperSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :job_scraper_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.json :target_roles, default: []
      t.json :target_locations, default: []
      t.json :keywords, default: []
      t.integer :min_salary
      t.boolean :remote_only, default: false
      t.boolean :auto_apply, default: false
      t.string :scrape_frequency, default: 'daily'
      t.datetime :last_scraped_at
      t.boolean :enabled, default: true
      t.string :experience_level
      t.integer :max_results_per_scrape, default: 20

      t.timestamps
    end
  end
end
