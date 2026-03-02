class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_completed

  def show
    @step = current_user.onboarding_step
  end

  def update
    step = params[:step].to_i
    current_user.update!(onboarding_step: step)

    if step >= 3
      current_user.update!(onboarding_completed: true)
      redirect_to dashboard_path, notice: "Welcome to RezumFit! You're all set."
    else
      redirect_to onboarding_path
    end
  end

  def skip
    current_user.update!(onboarding_completed: true)
    redirect_to dashboard_path
  end

  private

  def redirect_if_completed
    redirect_to dashboard_path if current_user.onboarding_completed?
  end
end
