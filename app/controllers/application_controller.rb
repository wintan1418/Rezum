class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Include helpers
  include CountriesHelper
  
  # Use custom layout for Devise authentication pages
  layout :layout_by_resource
  
  # Configure Devise permitted parameters
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :store_referral_code

  private

  def store_referral_code
    if params[:ref].present? && !user_signed_in?
      session[:referral_code] = params[:ref]
    end
  end

  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end
  
  def configure_permitted_parameters
    # Permit additional parameters for registration
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :first_name, :last_name, :country_code, :phone, :job_title, 
      :experience_level, :language, :timezone, :currency
    ])
    
    # Permit additional parameters for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :first_name, :last_name, :country_code, :phone, :job_title,
      :experience_level, :language, :timezone, :currency
    ])
  end
end
