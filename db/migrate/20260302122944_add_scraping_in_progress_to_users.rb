class AddScrapingInProgressToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :scraping_in_progress, :boolean, default: false
  end
end
