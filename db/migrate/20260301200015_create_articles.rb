class CreateArticles < ActiveRecord::Migration[7.2]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :author
      t.string :category
      t.string :meta_description
      t.string :meta_title
      t.string :featured_image_url
      t.text :content, null: false
      t.text :excerpt
      t.boolean :published, default: false
      t.datetime :published_at
      t.integer :reading_time, default: 5
      t.json :tags, default: []
      t.timestamps
    end
    add_index :articles, :slug, unique: true
    add_index :articles, :category
    add_index :articles, :published
  end
end
