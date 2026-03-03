class CreateHireMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :hire_messages do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.boolean :read, default: false, null: false

      t.timestamps
    end

    add_index :hire_messages, :read
    add_index :hire_messages, :created_at
  end
end
