class CreditPolicy
  COVER_LETTER = 1
  RESUME_OPTIMIZATION = 2
  ATS_SCORE = 2
  LINKEDIN_OPTIMIZATION = 2
  INTERVIEW_PREP = 3
  RESUME_WIZARD_UNLOCK = 10
  PITCH_DECK = 30

  FEATURE_COSTS = {
    cover_letter: COVER_LETTER,
    resume_optimization: RESUME_OPTIMIZATION,
    ats_score: ATS_SCORE,
    linkedin_optimization: LINKEDIN_OPTIMIZATION,
    interview_prep: INTERVIEW_PREP,
    resume_wizard_unlock: RESUME_WIZARD_UNLOCK,
    pitch_deck: PITCH_DECK
  }.freeze

  class << self
    def cost_for(feature)
      FEATURE_COSTS.fetch(feature)
    end

    def can_generate?(user, cost)
      user.has_active_subscription? || user.trial_active? || user.credits_remaining >= cost.to_i
    end

    def deduct!(user, amount)
      amount = amount.to_i
      return true if amount <= 0 || user.has_active_subscription?
      return false if user.credits_remaining < amount

      user.with_lock do
        return false if user.credits_remaining < amount

        user.update!(credits_remaining: user.credits_remaining - amount)
      end
      true
    end
  end
end
