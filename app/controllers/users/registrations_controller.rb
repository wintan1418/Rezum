class Users::RegistrationsController < Devise::RegistrationsController
  MIN_FILL_SECONDS = 3

  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_user_registration_path, alert: "Too many sign-ups from this network. Please try again later." }
  before_action :block_bots, only: :create

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

  private

  # A hidden field people never see (bots fill it in) and a minimum time on
  # the form (bots submit instantly). Bots get a quiet redirect, no account.
  def block_bots
    filled_honeypot = params[:website].present?
    started = params[:form_started_at].to_i
    too_fast = started.positive? && Time.current.to_i - started < MIN_FILL_SECONDS
    return unless filled_honeypot || too_fast

    Rails.logger.info("[signup] blocked bot from #{request.remote_ip} (honeypot=#{filled_honeypot} too_fast=#{too_fast})")
    redirect_to new_user_registration_path, notice: "Please check your details and try again."
  end
end
