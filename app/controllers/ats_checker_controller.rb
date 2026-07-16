class AtsCheckerController < ApplicationController
  before_action :check_rate_limit, only: :check

  layout "application"

  def show
    @rate_limited = already_used_free_check? && !user_signed_in?
  end

  def check
    unless params[:resume_file].present?
      return render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: "Please upload a resume file." })
    end

    # Extract text from uploaded file (fast, local) — the AI scoring runs in
    # a background job so this request never blocks on OpenAI
    processor = ResumeFileProcessorService.new(file: params[:resume_file])
    extraction = processor.process

    token = SecureRandom.hex(16)
    AtsCheckerJob.perform_later(token, extraction[:text])

    # Mark free check as used (for non-authenticated users)
    mark_free_check_used! unless user_signed_in?

    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/processing", locals: { token: token })
  rescue ResumeProcessingError => e
    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: e.message })
  rescue StandardError => e
    Rails.logger.error "ATS Checker error: #{e.message}"
    render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/error", locals: { message: "Something went wrong analyzing your resume. Please try again." })
  end

  # Polled by the processing panel until the background job stores a result
  def result
    token = params[:token].to_s
    unless token.match?(/\A\h{32}\z/)
      return head :bad_request
    end

    results = AtsCheckerJob.read_result(token)

    if results.nil?
      head :no_content
    elsif results[:error]
      render partial: "ats_checker/error", locals: { message: results[:error] }, layout: false
    else
      render partial: "ats_checker/results", locals: { results: results }, layout: false
    end
  end

  def capture_email
    unless allow_email_capture?
      return head :too_many_requests
    end

    email = params[:email]&.strip&.downcase
    if email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      Lead.find_or_create_by(email: email) do |lead|
        lead.source = "ats_checker"
        lead.ip_address = request.remote_ip
      end
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def check_rate_limit
    return if user_signed_in?

    if already_used_free_check?
      render turbo_stream: turbo_stream.replace("ats-results", partial: "ats_checker/rate_limited")
    end
  end

  def already_used_free_check?
    Rails.cache.exist?("ats_free:#{request.remote_ip}")
  end

  def mark_free_check_used!
    Rails.cache.write("ats_free:#{request.remote_ip}", true, expires_in: 30.days)
  end

  # Lead capture was previously unlimited — cap it so the leads table can't
  # be flooded from one address.
  def allow_email_capture?
    key = "ats_capture:#{request.remote_ip}"
    count = Rails.cache.increment(key, 1, expires_in: 1.hour)
    count ||= begin
      Rails.cache.write(key, 1, expires_in: 1.hour, raw: true)
      1
    end
    count <= 5
  end
end
