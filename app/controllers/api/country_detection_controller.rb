class Api::CountryDetectionController < ApplicationController
  before_action :set_cors_headers
  
  def detect
    context = CountryDetectionService.new(request, current_user).user_context
    
    render json: {
      country_code: context[:country]&.code,
      country_name: context[:country]&.name,
      country_flag: context[:country]&.flag_emoji,
      currency: context[:currency],
      language: context[:language],
      timezone: context[:timezone],
      phone_code: context[:country]&.phone_code,
      vat_rate: context[:country]&.vat_rate,
      payment_methods: context[:country]&.payment_methods,
      detected_from: detection_source(context)
    }
  end

  private

  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-Requested-With'
  end

  def detection_source(context)
    return 'user_profile' if current_user&.country_code.present?
    return 'ip_geolocation' if context[:ip_address] != '127.0.0.1'
    return 'browser_language' if context[:browser_languages].any?
    'default'
  end
end