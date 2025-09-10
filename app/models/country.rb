class Country < ApplicationRecord
  self.primary_key = 'code'
  
  has_many :users, foreign_key: 'country_code'
  
  validates :code, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true
  
  scope :active, -> { where(is_active: true) }
  scope :supported, -> { where(is_active: true).order(:name) }
  scope :by_region, ->(region) { joins("JOIN iso_countries ON countries.code = iso_countries.code").where("iso_countries.region = ?", region) }
  
  def flag_emoji
    code.codepoints.map { |c| (c + 127397).chr(Encoding::UTF_8) }.join
  end
  
  def display_name
    "#{flag_emoji} #{name}"
  end
  
  def display_name_with_code
    "#{flag_emoji} #{name} (#{code})"
  end
  
  def default_language
    supported_languages&.first || 'en'
  end
  
  # Get country data from ISO3166 gem for additional info
  def iso_country
    @iso_country ||= ISO3166::Country.new(code)
  end
  
  # Phone country code (e.g., "+1" for US)
  def phone_code
    return "+#{iso_country.country_code}" if iso_country&.country_code
    
    # Fallback mapping for common countries
    phone_codes = {
      'US' => '+1', 'CA' => '+1', 'GB' => '+44', 'AU' => '+61',
      'DE' => '+49', 'FR' => '+33', 'ES' => '+34', 'IT' => '+39',
      'NL' => '+31', 'BR' => '+55', 'IN' => '+91', 'MX' => '+52',
      'JP' => '+81', 'KR' => '+82', 'SG' => '+65'
    }
    phone_codes[code] || '+1'
  end
  
  # Phone number format example
  def phone_format_example
    case code
    when 'US', 'CA' then '(555) 123-4567'
    when 'GB' then '020 7946 0958'
    when 'DE' then '030 12345678'
    when 'FR' then '01 42 68 53 00'
    when 'ES' then '91 234 56 78'
    when 'IT' then '06 1234 5678'
    when 'NL' then '020 123 4567'
    when 'BR' then '(11) 99999-9999'
    when 'IN' then '+91 98765 43210'
    when 'MX' then '55 1234 5678'
    when 'JP' then '03-1234-5678'
    when 'KR' then '02-1234-5678'
    when 'SG' then '6123 4567'
    else "#{phone_code} 123456789"
    end
  end
  
  # Currency symbol
  def currency_symbol
    case currency
    when 'USD', 'CAD', 'AUD', 'SGD', 'MXN' then '$'
    when 'EUR' then '€'
    when 'GBP' then '£'
    when 'JPY' then '¥'
    when 'KRW' then '₩'
    when 'INR' then '₹'
    when 'BRL' then 'R$'
    else currency
    end
  end
  
  # Is this country in the European Union (for GDPR/VAT purposes)
  def in_eu?
    eu_countries = %w[AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE]
    eu_countries.include?(code)
  end
  
  # Tax display name
  def tax_name
    return 'VAT' if in_eu?
    case code
    when 'AU' then 'GST'
    when 'CA' then 'HST/GST'
    when 'IN' then 'GST'
    when 'JP' then 'Consumption Tax'
    when 'SG' then 'GST'
    else 'Tax'
    end
  end
  
  # Payment methods available for this country
  def available_payment_methods
    payment_methods.map do |method|
      case method
      when 'stripe' then { name: 'Credit/Debit Card', icon: 'credit-card', provider: 'stripe' }
      when 'paypal' then { name: 'PayPal', icon: 'paypal', provider: 'paypal' }
      when 'mollie' then { name: 'Bank Transfer', icon: 'bank', provider: 'mollie' }
      else { name: method.humanize, icon: 'payment', provider: method }
      end
    end
  end
  
  # Formatted VAT rate for display
  def vat_rate_display
    return 'No tax' if vat_rate.zero?
    "#{(vat_rate * 100).round(1)}% #{tax_name}"
  end
end
