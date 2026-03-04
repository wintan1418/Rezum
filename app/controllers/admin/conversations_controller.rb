module Admin
  class ConversationsController < BaseController
    before_action :set_conversation, only: [ :show, :reply, :close, :reopen ]

    def index
      @conversations = Conversation.recent.includes(:user, :messages)

      case params[:filter]
      when "closed"
        @conversations = @conversations.closed
      else
        @conversations = @conversations.open
      end
    end

    def show
      @messages = @conversation.messages.recent.includes(:user)
      # Mark messages as read by admin
      @conversation.messages.where.not(user: current_user).where(read: false).update_all(read: true)
    end

    def reply
      @message = @conversation.messages.build(user: current_user, body: params[:body])

      if @message.save
        @message.broadcast_to_conversation(viewing_user: current_user)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to admin_conversation_path(@conversation) }
        end
      else
        redirect_to admin_conversation_path(@conversation), alert: "Message could not be sent."
      end
    end

    def close
      @conversation.update(status: "closed")
      redirect_to admin_conversations_path, notice: "Conversation closed."
    end

    def reopen
      @conversation.update(status: "open")
      redirect_to admin_conversation_path(@conversation), notice: "Conversation reopened."
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end
  end
end
