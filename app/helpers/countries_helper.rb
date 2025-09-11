module CountriesHelper
  # Generate country select options for forms using ISO3166 gem (ALL countries)
  def country_select_options(selected_country_code = nil, active_only: false)
    # Get ALL countries from ISO3166 gem - no more limited Country model
    countries = ISO3166::Country.all.map do |country|
      # Handle timezone properly - it can be an array or nil
      timezone = begin
        if country.respond_to?(:timezones) && country.timezones.respond_to?(:first)
          country.timezones.first
        elsif country.respond_to?(:timezones) && country.timezones.is_a?(Array)
          country.timezones.first
        else
          'UTC'
        end
      rescue
        'UTC'
      end
      
      # Generate flag emoji from country code
      flag = country.alpha2.codepoints.map { |c| (c + 127397).chr(Encoding::UTF_8) }.join
      
      # Get phone example for the country
      phone_example = get_phone_example(country.alpha2)
      
      [
        "#{flag} #{country.common_name}",
        country.alpha2,
        {
          'data-currency' => country.currency_code,
          'data-phone-code' => "+#{country.country_code}",
          'data-phone-example' => phone_example,
          'data-timezone' => timezone,
          selected: country.alpha2 == selected_country_code
        }
      ]
    end
    
    # Sort countries alphabetically by name
    countries.sort_by(&:first)
  end

  # Generate currency select options
  def currency_select_options(selected_currency = nil)
    Country.active.distinct.pluck(:currency).compact.sort.map do |currency|
      country = Country.active.find_by(currency: currency)
      symbol = country&.currency_symbol || currency
      
      ["#{symbol} #{currency}", currency, { selected: currency == selected_currency }]
    end
  end

  # Generate timezone select options grouped by region
  def timezone_select_options(selected_timezone = nil)
    Country.active.group_by { |c| c.timezone.split('/').first }.map do |region, countries|
      [
        region.humanize,
        countries.map do |country|
          timezone_display = "#{country.timezone.split('/').last.humanize} (#{country.display_name})"
          [timezone_display, country.timezone, { selected: country.timezone == selected_timezone }]
        end
      ]
    end
  end

  # Format currency amount with proper symbol
  def format_currency(amount, currency_code)
    country = Country.active.find_by(currency: currency_code)
    symbol = country&.currency_symbol || currency_code
    
    if %w[JPY KRW].include?(currency_code)
      # No decimals for Japanese Yen and Korean Won
      "#{symbol}#{number_with_delimiter(amount.to_i)}"
    else
      "#{symbol}#{number_with_precision(amount, precision: 2, delimiter: ',')}"
    end
  end

  # Display country flag emoji
  def country_flag(country_code)
    return '🌍' if country_code.blank?
    
    country = Country.find_by(code: country_code.upcase)
    country&.flag_emoji || '🌍'
  end

  # Phone number input helpers
  def phone_input_placeholder(country_code)
    return 'Enter phone number' if country_code.blank?
    
    country = Country.find_by(code: country_code.upcase)
    country&.phone_format_example || 'Enter phone number'
  end

  def phone_country_code(country_code)
    return '+1' if country_code.blank?
    
    country = Country.find_by(code: country_code.upcase)
    country&.phone_code || '+1'
  end

  # VAT/Tax information
  def tax_info_for_country(country_code)
    return nil if country_code.blank?
    
    country = Country.find_by(code: country_code.upcase)
    return nil unless country&.vat_rate&.positive?
    
    {
      rate: country.vat_rate,
      display: country.vat_rate_display,
      name: country.tax_name,
      is_eu: country.in_eu?
    }
  end

  # Payment methods for country
  def payment_methods_for_country(country_code)
    return [] if country_code.blank?
    
    country = Country.find_by(code: country_code.upcase)
    country&.available_payment_methods || []
  end

  # Business hours indicator
  def business_hours_indicator(timezone)
    return content_tag(:span, '🌍 Unknown timezone', class: 'text-gray-500 text-sm') if timezone.blank?
    
    begin
      current_time = Time.current.in_time_zone(timezone)
      hour = current_time.hour
      is_business_hours = (9..17).include?(hour) && !current_time.weekend?
      
      status_class = is_business_hours ? 'text-green-600' : 'text-gray-500'
      status_icon = is_business_hours ? '🟢' : '🌙'
      time_display = current_time.strftime('%H:%M')
      
      content_tag(:span, "#{status_icon} #{time_display}", class: "#{status_class} text-sm")
    rescue
      content_tag(:span, '🌍 Invalid timezone', class: 'text-gray-500 text-sm')
    end
  end

  # Language display
  def language_display(language_code)
    languages = {
      'en' => '🇺🇸 English',
      'es' => '🇪🇸 Español',
      'fr' => '🇫🇷 Français',
      'de' => '🇩🇪 Deutsch',
      'pt' => '🇧🇷 Português',
      'it' => '🇮🇹 Italiano',
      'nl' => '🇳🇱 Nederlands'
    }
    
    languages[language_code] || language_code&.humanize || 'Unknown'
  end

  # Get user's detected location info
  def user_location_context(request, user = nil)
    @location_context ||= CountryDetectionService.new(request, user).user_context
  end
  
  private
  
  # Get phone number example for country
  def get_phone_example(country_code)
    examples = {
      'US' => '(555) 123-4567',
      'CA' => '(555) 123-4567', 
      'GB' => '020 7946 0958',
      'DE' => '030 12345678',
      'FR' => '01 42 34 56 78',
      'ES' => '91 123 45 67',
      'IT' => '06 1234 5678',
      'NL' => '020 123 4567',
      'AU' => '02 9374 4000',
      'JP' => '03-1234-5678',
      'CN' => '010 1234 5678',
      'IN' => '022 1234 5678',
      'BR' => '(11) 91234-5678',
      'MX' => '55 1234 5678',
      'AR' => '011 1234-5678',
      'CL' => '2 2123 4567',
      'CO' => '1 234 5678',
      'PE' => '1 234 5678',
      'VE' => '212 123 4567',
      'NG' => '0803 123 4567',
      'GH' => '020 123 4567',
      'KE' => '020 123 4567',
      'ZA' => '011 123 4567',
      'EG' => '02 1234 5678',
      'MA' => '0522 12 34 56',
      'SE' => '08-123 456 78',
      'NO' => '22 12 34 56',
      'DK' => '32 12 34 56',
      'FI' => '09 123 45678',
      'CH' => '044 123 45 67',
      'AT' => '01 123 45 67',
      'BE' => '02 123 45 67',
      'IE' => '01 123 4567',
      'NZ' => '09 123 4567',
      'SG' => '6123 4567',
      'HK' => '2123 4567',
      'TW' => '02 1234 5678',
      'KR' => '02-123-4567',
      'TH' => '02 123 4567',
      'MY' => '03-1234 5678',
      'ID' => '021 1234 5678',
      'PH' => '02 1234 5678',
      'VN' => '024 1234 5678'
    }
    
    examples[country_code] || '123 456 7890'
  end
end