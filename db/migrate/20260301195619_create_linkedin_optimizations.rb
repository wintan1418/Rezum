class CreateLinkedinOptimizations < ActiveRecord::Migration[7.2]
  def change
    create_table :linkedin_optimizations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, foreign_key: true
      t.string :target_role
      t.text :current_headline
      t.text :optimized_headline
      t.text :current_about
      t.text :optimized_about
      t.text :current_experience
      t.text :optimized_experience
      t.json :suggestions, default: []
      t.string :status, default: 'draft'
      t.string :provider
      t.timestamps
    end
  end
end
