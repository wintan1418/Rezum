class CreatePitchDecks < ActiveRecord::Migration[7.2]
  def change
    create_table :pitch_decks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :tagline
      t.string :industry
      t.string :stage
      t.string :funding_ask
      t.string :status, null: false, default: "draft"
      t.string :template, null: false, default: "sequoia"
      t.string :color_scheme, null: false, default: "professional"
      t.jsonb :inputs, null: false, default: {}
      t.text :error_message
      t.integer :credits_charged, default: 0
      t.datetime :generated_at
      t.timestamps

      t.index [:user_id, :status]
    end

    create_table :pitch_deck_slides do |t|
      t.references :pitch_deck, null: false, foreign_key: true
      t.string :slide_type, null: false
      t.integer :position, null: false
      t.string :title
      t.jsonb :content, null: false, default: {}
      t.text :speaker_notes
      t.boolean :visible, null: false, default: true
      t.timestamps

      t.index [:pitch_deck_id, :position]
      t.index [:pitch_deck_id, :slide_type]
    end
  end
end
