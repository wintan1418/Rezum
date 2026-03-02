class ReferralService
  REFERRER_CREDITS = 5
  REFEREE_BONUS = 2

  def self.apply_referral(referrer, referee)
    return if referrer.nil? || referee.nil? || referrer == referee
    return if referee.referral_bonus_applied?

    ActiveRecord::Base.transaction do
      referrer.add_credits(REFERRER_CREDITS)
      referrer.increment!(:referral_credits_earned, REFERRER_CREDITS)
      referee.add_credits(REFEREE_BONUS)
      referee.update!(referral_bonus_applied: true)
    end
  end
end
