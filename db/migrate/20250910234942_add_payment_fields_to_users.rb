class AddPaymentFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :stripe_customer_id, :string
  end
end
