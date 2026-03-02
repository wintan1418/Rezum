class AddOnboardingToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :onboarding_completed, :boolean, default: false
    add_column :users, :onboarding_step, :integer, default: 0
  end
end
