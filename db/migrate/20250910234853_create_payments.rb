class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_payment_intent_id
      t.integer :amount_cents
      t.string :currency
      t.string :status
      t.string :description
      t.integer :credits_purchased

      t.timestamps
    end
  end
end
