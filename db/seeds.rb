# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

# Load country data
load Rails.root.join('db', 'seeds', 'countries.rb')
