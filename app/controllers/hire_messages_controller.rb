class HireMessagesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def create
    if rate_limited?
      render turbo_stream: turbo_stream.replace("hire-modal-content", partial: "hire_messages/rate_limited")
      return
    end

    @hire_message = HireMessage.new(hire_message_params)

    if @hire_message.save
      mark_rate_limit!
      UserMailer.hire_message_notification(@hire_message).deliver_later
      render turbo_stream: turbo_stream.replace("hire-modal-content", partial: "hire_messages/success")
    else
      render turbo_stream: turbo_stream.replace("hire-modal-content", partial: "hire_messages/form", locals: { hire_message: @hire_message })
    end
  end

  private

  def hire_message_params
    params.require(:hire_message).permit(:name, :email, :message)
  end

  def rate_limited?
    Rails.cache.read("hire_msg:#{request.remote_ip}").to_i >= 3
  end

  def mark_rate_limit!
    key = "hire_msg:#{request.remote_ip}"
    count = Rails.cache.read(key).to_i
    Rails.cache.write(key, count + 1, expires_in: 24.hours)
  end
end
