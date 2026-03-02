class ReferralsController < ApplicationController
  before_action :authenticate_user!

  def show
    @referral_code = current_user.referral_code
    @referral_link = root_url(ref: current_user.referral_code)
    @referrals = current_user.referrals.order(created_at: :desc)
    @referral_credits_earned = current_user.referral_credits_earned || 0
  end
end
