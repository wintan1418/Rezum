class RenameStripeToPaystack < ActiveRecord::Migration[7.2]
  def change
    # Users
    rename_column :users, :stripe_customer_id, :paystack_customer_code

    # Payments
    rename_column :payments, :stripe_payment_intent_id, :paystack_reference

    # Subscriptions
    rename_column :subscriptions, :stripe_subscription_id, :paystack_subscription_code
  end
end
