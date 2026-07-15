class AddLanguageToCoverLetters < ActiveRecord::Migration[7.2]
  def change
    add_column :cover_letters, :language, :string, null: false, default: "en"
  end
end
