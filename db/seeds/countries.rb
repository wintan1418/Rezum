# Countries seed data for ReZum using official ISO3166 data
require 'countries'

# Priority countries with all data defined (major job markets)
priority_countries_data = {
  'US' => {
    name: 'United States',
    currency: 'USD',
    timezone: 'America/New_York',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.0
  },
  'CA' => {
    name: 'Canada',
    currency: 'CAD',
    timezone: 'America/Toronto',
    languages: ['en', 'fr'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.0
  },
  'GB' => {
    name: 'United Kingdom',
    currency: 'GBP',
    timezone: 'Europe/London',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.20
  },
  'AU' => {
    name: 'Australia',
    currency: 'AUD',
    timezone: 'Australia/Sydney',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.10
  },
  'DE' => {
    name: 'Germany',
    currency: 'EUR',
    timezone: 'Europe/Berlin',
    languages: ['de', 'en'],
    payment_methods: ['stripe', 'paypal', 'mollie'],
    vat_rate: 0.19
  },
  'FR' => {
    name: 'France',
    currency: 'EUR',
    timezone: 'Europe/Paris',
    languages: ['fr', 'en'],
    payment_methods: ['stripe', 'paypal', 'mollie'],
    vat_rate: 0.20
  },
  'ES' => {
    name: 'Spain',
    currency: 'EUR',
    timezone: 'Europe/Madrid',
    languages: ['es', 'en'],
    payment_methods: ['stripe', 'paypal', 'mollie'],
    vat_rate: 0.21
  },
  'IT' => {
    name: 'Italy',
    currency: 'EUR',
    timezone: 'Europe/Rome',
    languages: ['it', 'en'],
    payment_methods: ['stripe', 'paypal', 'mollie'],
    vat_rate: 0.22
  },
  'NL' => {
    name: 'Netherlands',
    currency: 'EUR',
    timezone: 'Europe/Amsterdam',
    languages: ['nl', 'en'],
    payment_methods: ['stripe', 'paypal', 'mollie'],
    vat_rate: 0.21
  },
  'BR' => {
    name: 'Brazil',
    currency: 'BRL',
    timezone: 'America/Sao_Paulo',
    languages: ['pt', 'en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.0
  },
  'IN' => {
    name: 'India',
    currency: 'INR',
    timezone: 'Asia/Kolkata',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.18
  },
  'MX' => {
    name: 'Mexico',
    currency: 'MXN',
    timezone: 'America/Mexico_City',
    languages: ['es', 'en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.16
  },
  'JP' => {
    name: 'Japan',
    currency: 'JPY',
    timezone: 'Asia/Tokyo',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.10
  },
  'KR' => {
    name: 'South Korea',
    currency: 'KRW',
    timezone: 'Asia/Seoul',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.10
  },
  'SG' => {
    name: 'Singapore',
    currency: 'SGD',
    timezone: 'Asia/Singapore',
    languages: ['en'],
    payment_methods: ['stripe', 'paypal'],
    vat_rate: 0.07
  }
}

created_count = 0
updated_count = 0

# Seed priority countries (active by default)
priority_countries_data.each do |country_code, data|
  country = Country.find_or_initialize_by(code: country_code)
  
  country_attrs = {
    code: country_code,
    name: data[:name],
    currency: data[:currency],
    timezone: data[:timezone],
    supported_languages: data[:languages],
    payment_methods: data[:payment_methods],
    vat_rate: data[:vat_rate],
    is_active: true
  }
  
  if country.persisted?
    # Update existing country if any attributes changed
    country.assign_attributes(country_attrs)
    if country.changed?
      country.save!
      updated_count += 1
      puts "✅ Updated country: #{country.display_name}"
    else
      puts "🔸 Country unchanged: #{country.display_name}"
    end
  else
    # Create new country
    country.assign_attributes(country_attrs)
    country.save!
    created_count += 1
    puts "🆕 Created country: #{country.display_name}"
  end
end

# Add more countries from ISO3166 as inactive (for future expansion)
additional_countries = ['SE', 'DK', 'NO', 'FI', 'BE', 'AT', 'IE', 'PT', 'CH', 'CZ', 'PL', 'HU', 'RO', 'GR', 'IL', 'ZA', 'NZ', 'HK', 'TW', 'MY', 'TH', 'ID', 'PH', 'VN']

additional_countries.each do |country_code|
  next if Country.exists?(code: country_code)
  
  iso_country = ISO3166::Country.new(country_code)
  next unless iso_country
  
  begin
    Country.create!({
      code: country_code,
      name: iso_country.name,
      currency: iso_country.currency&.iso_code || 'USD',
      timezone: 'UTC', # Default timezone for inactive countries
      supported_languages: ['en'],
      payment_methods: ['stripe', 'paypal'],
      vat_rate: 0.0,
      is_active: false # Inactive by default
    })
    puts "➕ Added inactive country: #{iso_country.name} (#{country_code})"
  rescue => e
    puts "❌ Error adding #{country_code}: #{e.message}"
  end
end

puts "\n✅ Country seeding complete!"
puts "📊 Statistics:"
puts "  - 🆕 Created: #{created_count} countries"
puts "  - ⚡ Updated: #{updated_count} countries"  
puts "  - 🟢 Active countries: #{Country.active.count}"
puts "  - 📍 Total countries: #{Country.count}"
puts "  - 💰 Supported currencies: #{Country.active.distinct.pluck(:currency).compact.sort.join(', ')}"

# Verify our priority countries are all active
priority_countries_data.keys.each do |code|
  country = Country.find_by(code: code)
  if country&.is_active?
    puts "✅ #{country.display_name} - Active"
  else
    puts "❌ #{code} - Missing or Inactive"
  end
end