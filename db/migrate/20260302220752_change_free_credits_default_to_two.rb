class ChangeFreeCreditsDefaultToTwo < ActiveRecord::Migration[7.2]
  def change
    change_column_default :users, :credits_remaining, from: 3, to: 2
  end
end
