module ApplicationHelper
  def country_select_options(selected_country = nil)
    # Get ALL countries from the countries gem - no filtering, no hardcoding
    countries = ISO3166::Country.all.map do |country|
      [country.common_name, country.alpha2]
    end
    
    # Sort countries alphabetically by name  
    sorted_countries = countries.sort_by(&:first)
    
    # If a selected country is provided, mark it as selected
    if selected_country.present?
      sorted_countries.map do |name, code|
        if code == selected_country
          [name, code, { selected: true }]
        else
          [name, code]
        end
      end
    else
      sorted_countries
    end
  end
  
  def country_phone_code(country_code)
    return '+1' if country_code.blank?
    
    country = ISO3166::Country.find_country_by_alpha2(country_code)
    return '+1' unless country
    
    # Get the international calling code - the method is actually `country_code`
    calling_code = country.country_code
    calling_code ? "+#{calling_code}" : '+1'
  end
  
  def country_currency(country_code)
    return 'USD' if country_code.blank?
    
    country = ISO3166::Country.find_country_by_alpha2(country_code)
    return 'USD' unless country
    
    # Get the primary currency
    currency = country.currency_code
    currency.present? ? currency : 'USD'
  end
  
  def country_timezone(country_code)
    return 'UTC' if country_code.blank?
    
    country = ISO3166::Country.find_country_by_alpha2(country_code)
    return 'UTC' unless country
    
    # Get the primary timezone (countries can have multiple)
    timezones = country.timezones
    timezones.present? ? timezones.first : 'UTC'
  end
  
  def format_phone_example(country_code)
    case country_code
    when 'US', 'CA'
      '(555) 123-4567'
    when 'GB'
      '020 7946 0958'
    when 'DE'
      '030 12345678'
    when 'FR'
      '01 42 34 56 78'
    when 'AU'
      '02 9374 4000'
    when 'NL'
      '020 123 4567'
    when 'SE'
      '08-123 456 78'
    when 'NO'
      '22 12 34 56'
    when 'DK'
      '32 12 34 56'
    else
      '123 456 7890'
    end
  end
  
  def is_eu_country?(country_code)
    return false if country_code.blank?
    
    country = ISO3166::Country.find_country_by_alpha2(country_code)
    return false unless country
    
    # Check if country is in the EU
    country.in_eu?
  rescue
    false
  end
end
