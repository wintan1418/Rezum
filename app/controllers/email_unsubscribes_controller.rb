class EmailUnsubscribesController < ApplicationController
  def show
    user = User.find_by(email: params[:email], referral_code: params[:token])
    if user
      user.update!(unsubscribed_at: Time.current, marketing_consent: false)
      @unsubscribed = true
    else
      @unsubscribed = false
    end
  end
end
