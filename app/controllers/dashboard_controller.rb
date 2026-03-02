class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if !current_user.onboarding_completed? && current_user.resumes.count == 0
      redirect_to onboarding_path and return
    end

    @resumes = current_user.resumes.recent.limit(5).includes(:cover_letters)
    @cover_letters = current_user.cover_letters.recent.limit(5).includes(:resume)
    @resumes_count = current_user.resumes.count
    @cover_letters_count = current_user.cover_letters.count
    @optimized_count = current_user.resumes.optimized.count
    @avg_ats_score = current_user.resumes.where.not(ats_score: nil).average(:ats_score)&.round(0)
    @credits_remaining = current_user.credits_remaining
    @subscription = current_user.current_subscription
    @recent_activity = build_recent_activity
  end

  private

  def build_recent_activity
    resumes = current_user.resumes.recent.limit(5).map do |r|
      { type: "resume", record: r, date: r.updated_at,
        title: r.target_role || "Resume",
        action: r.optimized? ? "optimized" : "created" }
    end

    letters = current_user.cover_letters.recent.limit(5).map do |cl|
      { type: "cover_letter", record: cl, date: cl.updated_at,
        title: "#{cl.target_role} at #{cl.company_name}",
        action: cl.generated? ? "generated" : "created" }
    end

    (resumes + letters).sort_by { |a| a[:date] }.reverse.first(5)
  end
end
