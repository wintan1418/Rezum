class CreateCountries < ActiveRecord::Migration[7.2]
  def change
    create_table :countries, id: false do |t|
      t.string :code, limit: 2, primary_key: true
      t.string :name, null: false
      t.string :currency, limit: 3, default: 'USD'
      t.string :timezone
      t.json :supported_languages, default: ['en']
      t.json :payment_methods, default: []
      t.decimal :vat_rate, precision: 5, scale: 4, default: 0
      t.boolean :is_active, default: true

      t.timestamps
      
      t.index :name
      t.index :currency
      t.index :is_active
    end
  end
end
