module Admin
  class HireMessagesController < BaseController
    before_action :set_message, only: [ :show, :destroy ]

    def index
      @messages = HireMessage.recent
      @unread_count = HireMessage.unread.count
    end

    def show
      @message.update(read: true) unless @message.read?
    end

    def destroy
      @message.destroy
      redirect_to admin_hire_messages_path, notice: "Message deleted."
    end

    private

    def set_message
      @message = HireMessage.find(params[:id])
    end
  end
end
