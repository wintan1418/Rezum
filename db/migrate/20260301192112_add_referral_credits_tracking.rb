class AddReferralCreditsTracking < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :referral_credits_earned, :integer, default: 0
    add_column :users, :referral_bonus_applied, :boolean, default: false
  end
end
