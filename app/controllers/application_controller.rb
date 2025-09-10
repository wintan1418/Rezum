class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Include helpers
  include CountriesHelper
  
  # Use custom layout for Devise authentication pages
  layout :layout_by_resource

  private

  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end
end
