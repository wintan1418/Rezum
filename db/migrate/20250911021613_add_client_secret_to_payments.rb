class AddClientSecretToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :client_secret, :string
  end
end
