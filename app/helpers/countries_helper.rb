module CountriesHelper
  # Generate country select options for forms
  def country_select_options(selected_country_code = nil, active_only: true)
    countries = active_only ? Country.active : Country.all
    
    countries.map do |country|
      [
        country.display_name,
        country.code,
        {
          'data-currency' => country.currency,
          'data-currency-symbol' => country.currency_symbol,
          'data-phone-code' => country.phone_code,
          'data-phone-example' => country.phone_format_example,
          'data-timezone' => country.timezone,
          'data-vat-rate' => country.vat_rate,
          'data-vat-display' => country.vat_rate_display,
          'data-languages' => country.supported_languages.join(','),
          'data-payment-methods' => country.payment_methods.join(','),
          selected: country.code == selected_country_code
        }
      ]
    end
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
end