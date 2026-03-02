# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

# Load country data
load Rails.root.join('db', 'seeds', 'countries.rb')

# Load blog articles
load Rails.root.join('db', 'seeds', 'articles.rb')

# Load test accounts (development only)
if Rails.env.development?
  load Rails.root.join('db', 'seeds', 'test_accounts.rb')
end
