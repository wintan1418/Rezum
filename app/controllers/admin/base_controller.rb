module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin!
    before_action :set_admin_badge_counts

    private

    def set_admin_badge_counts
      @unread_conversations = Rails.cache.fetch("admin:unread_conversations", expires_in: 5.minutes) do
        Conversation.open.joins(:messages)
          .where(messages: { read: false })
          .where.not(messages: { user_id: current_user.id })
          .distinct.count
      end
      @unread_hire = Rails.cache.fetch("admin:unread_hire", expires_in: 5.minutes) do
        HireMessage.unread.count
      end
    end

    def require_admin!
      unless current_user&.admin?
        redirect_to root_path, alert: "You don't have permission to access this area."
      end
    end
  end
end
