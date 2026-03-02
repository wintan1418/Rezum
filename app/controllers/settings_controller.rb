class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def update
    if current_user.update(user_settings_params)
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_account
    current_user.destroy
    reset_session
    redirect_to root_path, notice: "Your account has been deleted."
  end

  private

  def user_settings_params
    params.require(:user).permit(
      :first_name, :last_name, :phone, :job_title,
      :country_code, :language, :timezone, :currency,
      :linkedin_url, :portfolio_url, :bio,
      :marketing_consent, :avatar
    )
  end
end
