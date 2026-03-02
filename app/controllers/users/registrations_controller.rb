class Users::RegistrationsController < Devise::RegistrationsController
  # POST /resource
  def create
    super do |resource|
      # Auto-confirm the user so they can sign in immediately
      if resource.persisted? && resource.respond_to?(:confirmed_at)
        resource.update_column(:confirmed_at, Time.current) if resource.confirmed_at.nil?
      end

      # Apply referral bonus if a referral code was stored in session
      if resource.persisted? && session[:referral_code].present?
        referrer = User.find_by(referral_code: session[:referral_code])
        if referrer && referrer != resource
          resource.update_column(:referred_by_id, referrer.id)
          ReferralService.apply_referral(referrer, resource)
        end
        session.delete(:referral_code)
      end
    end
  end

  protected

  def after_sign_up_path_for(resource)
    stored_location_for(:user) || super
  end
end
