# Service for detecting user's country from various sources
class CountryDetectionService
  def initialize(request, user = nil)
    @request = request
    @user = user
  end

  def detect_country
    country_code = detect_country_code
    Country.find_by(code: country_code) || Country.find_by(code: 'US')
  end

  def detect_language
    # Priority: user preference > browser language > country default > English
    user_language = @user&.language
    browser_language = detect_from_accept_language
    country_language = detect_country&.default_language
    
    [user_language, browser_language, country_language, 'en'].compact.find do |lang|
      I18n.available_locales.include?(lang.to_sym)
    end || 'en'
  end

  def detect_timezone
    # Priority: user preference > country timezone > UTC
    user_timezone = @user&.timezone
    country_timezone = detect_country&.timezone
    
    [user_timezone, country_timezone, 'UTC'].compact.first
  end

  def detect_currency
    # Priority: user preference > country currency > USD
    user_currency = @user&.currency
    country_currency = detect_country&.currency
    
    [user_currency, country_currency, 'USD'].compact.first
  end

  # Get comprehensive user context
  def user_context
    {
      country: detect_country,
      language: detect_language,
      timezone: detect_timezone,
      currency: detect_currency,
      ip_address: @request.remote_ip,
      user_agent: @request.user_agent,
      browser_languages: extract_browser_languages
    }
  end

  private

  def detect_country_code
    # Priority: URL param > user setting > headers > IP geolocation > default
    url_country = @request.params[:country]
    user_country = @user&.country_code
    header_country = detect_from_headers
    ip_country = detect_from_ip
    
    [url_country, user_country, header_country, ip_country, 'US'].compact.first.upcase
  end

  def detect_from_headers
    # Check various CDN and proxy headers
    headers_to_check = [
      'CF-IPCountry',           # Cloudflare
      'X-Country-Code',         # Custom header
      'CloudFront-Viewer-Country', # AWS CloudFront
      'X-Vercel-IP-Country',    # Vercel
      'Fly-Region'              # Fly.io (needs mapping)
    ]
    
    headers_to_check.each do |header|
      country_code = @request.headers[header]
      return country_code.upcase if country_code.present? && valid_country_code?(country_code)
    end
    
    nil
  end

  def detect_from_ip
    return nil if Rails.env.development? || @request.remote_ip == '127.0.0.1'
    
    # Cache IP lookups for 1 day to avoid rate limits
    Rails.cache.fetch("country_for_ip_#{@request.remote_ip}", expires_in: 1.day) do
      begin
        result = Geocoder.search(@request.remote_ip).first
        country_code = result&.country_code
        
        if country_code.present? && valid_country_code?(country_code)
          Rails.logger.info "IP #{@request.remote_ip} detected as country: #{country_code}"
          country_code.upcase
        else
          Rails.logger.warn "Could not detect country from IP #{@request.remote_ip}"
          nil
        end
      rescue => e
        Rails.logger.error "Geocoding failed for IP #{@request.remote_ip}: #{e.message}"
        nil
      end
    end
  end

  def detect_from_accept_language
    return nil unless @request.headers['Accept-Language']
    
    # Parse Accept-Language header (e.g., "en-US,en;q=0.9,es;q=0.8")
    languages = @request.headers['Accept-Language']
                        .split(',')
                        .map { |lang| lang.split(';').first.strip.split('-').first.downcase }
                        .uniq
    
    # Return first language that we support
    languages.find { |lang| I18n.available_locales.include?(lang.to_sym) }
  rescue
    nil
  end

  def extract_browser_languages
    return [] unless @request.headers['Accept-Language']
    
    @request.headers['Accept-Language']
            .split(',')
            .map do |lang_with_quality|
              lang = lang_with_quality.split(';').first.strip
              quality = lang_with_quality.match(/q=([0-9.]+)/)&.captures&.first&.to_f || 1.0
              { language: lang, quality: quality }
            end
            .sort_by { |item| -item[:quality] }
  rescue
    []
  end

  def valid_country_code?(code)
    code.present? && code.length == 2 && ISO3166::Country.new(code.upcase).present?
  rescue
    false
  end
end