module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :toggle_admin, :toggle_disable ]

    def index
      @users = User.recent
      @users = @users.search(params[:q]) if params[:q].present?

      case params[:filter]
      when "subscribers"
        @users = @users.subscribers
      when "free"
        @users = @users.where.not(id: Subscription.where(status: :active).select(:user_id))
      when "disabled"
        @users = @users.where.not(disabled_at: nil)
      when "admins"
        @users = @users.admins
      end

      @users = @users.page(params[:page]) if @users.respond_to?(:page)
      @users = @users.limit(50) unless @users.respond_to?(:page)
    end

    def show
      @resumes = @user.resumes.order(created_at: :desc).limit(10)
      @cover_letters = @user.cover_letters.order(created_at: :desc).limit(10)
      @payments = @user.payments.order(created_at: :desc).limit(10)
    end

    def toggle_admin
      @user.update(admin: !@user.admin?)
      redirect_to admin_user_path(@user), notice: "#{@user.full_name} is now #{@user.admin? ? 'an admin' : 'a regular user'}."
    end

    def toggle_disable
      if @user.disabled?
        @user.update(disabled_at: nil)
        redirect_to admin_user_path(@user), notice: "#{@user.full_name} has been enabled."
      else
        @user.update(disabled_at: Time.current)
        redirect_to admin_user_path(@user), notice: "#{@user.full_name} has been disabled."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
