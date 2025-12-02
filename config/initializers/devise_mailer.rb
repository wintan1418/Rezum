# Configure Devise mailer settings
Devise.setup do |config|
  # Configure the e-mail address which will be shown in Devise::Mailer
  config.mailer_sender = 'noreply@rezum.ai'
  
  # Configure the confirmation period
  config.confirm_within = 3.days
  
  # Allow unconfirmed access for a period
  config.allow_unconfirmed_access_for = 2.days
  
  # Automatically confirm new accounts created via OAuth
  config.reconfirmable = true
end