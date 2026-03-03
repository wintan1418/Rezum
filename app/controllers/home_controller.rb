class HomeController < ApplicationController
  layout false, only: [ :index ]

  def index
    redirect_to dashboard_path if user_signed_in? && params[:preview].blank?
  end
end
