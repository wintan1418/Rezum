class ChatController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [ :show, :send_message ]

  def index
    @conversations = current_user.conversations.recent
  end

  def show
    @messages = @conversation.messages.recent
    # Mark messages as read
    @conversation.messages.where.not(user: current_user).where(read: false).update_all(read: true)
  end

  def create
    @conversation = current_user.conversations.build(
      subject: params[:subject].presence || "Support Request",
      status: "open",
      last_message_at: Time.current
    )

    if @conversation.save
      # Create the first message if body provided
      if params[:body].present?
        msg = @conversation.messages.create!(user: current_user, body: params[:body])
        msg.broadcast_to_conversation(viewing_user: current_user)
      end
      redirect_to chat_path(@conversation)
    else
      redirect_to chat_index_path, alert: "Could not start conversation."
    end
  end

  def send_message
    @message = @conversation.messages.build(user: current_user, body: params[:body])

    if @message.save
      @message.broadcast_to_conversation(viewing_user: current_user)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path(@conversation) }
      end
    else
      redirect_to chat_path(@conversation), alert: "Message could not be sent."
    end
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  end
end
