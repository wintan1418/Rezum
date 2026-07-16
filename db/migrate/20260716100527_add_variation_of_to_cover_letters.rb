class AddVariationOfToCoverLetters < ActiveRecord::Migration[7.2]
  def change
    add_reference :cover_letters, :variation_of, null: true, foreign_key: { to_table: :cover_letters }
  end
end
