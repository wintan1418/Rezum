class CreateResumeSections < ActiveRecord::Migration[7.2]
  def change
    create_table :resume_sections do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :section_type, null: false
      t.json :content, default: {}
      t.integer :position, default: 0
      t.boolean :visible, default: true
      t.timestamps
    end
    add_index :resume_sections, [:resume_id, :position]
  end
end
