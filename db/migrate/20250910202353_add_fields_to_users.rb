class AddFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    # Basic Profile
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :phone, :string
    add_column :users, :job_title, :string
    add_column :users, :company, :string
    add_column :users, :bio, :text
    
    # Internationalization
    add_column :users, :country_code, :string, limit: 2
    add_column :users, :timezone, :string
    add_column :users, :language, :string, default: 'en'
    add_column :users, :currency, :string, default: 'USD'
    
    # Experience & Industry
    add_column :users, :industry, :string
    add_column :users, :experience_level, :integer, default: 0
    add_column :users, :linkedin_url, :string
    add_column :users, :portfolio_url, :string
    
    # Account Management
    add_column :users, :credits_remaining, :integer, default: 3
    add_column :users, :total_generations, :integer, default: 0
    add_column :users, :subscription_status, :integer, default: 0
    add_column :users, :trial_ends_at, :datetime
    add_column :users, :last_active_at, :datetime
    
    # Privacy & Marketing
    add_column :users, :marketing_consent, :boolean, default: false
    add_column :users, :privacy_settings, :json, default: {}
    add_column :users, :notification_preferences, :json, default: {}
    
    # Referral System
    add_column :users, :referral_code, :string
    add_column :users, :referred_by_id, :bigint
    
    # OAuth
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    
    # Add indexes for performance
    add_index :users, :country_code
    add_index :users, :subscription_status
    add_index :users, :referral_code, unique: true
    add_index :users, :last_active_at
    add_index :users, [:provider, :uid]
    add_index :users, :referred_by_id
  end
end
