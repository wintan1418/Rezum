class CoverLettersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, except: [ :index ]
  before_action :set_cover_letter, only: [ :show, :edit, :update, :destroy, :regenerate, :generate_variations, :preview, :download ]

  def index
    @cover_letters = current_user.cover_letters.recent.includes(:resume)
    @sent_count = @cover_letters.where(status: "sent").count
    @response_rate = calculate_response_rate
    @companies_count = @cover_letters.where.not(company_name: [ nil, "" ]).distinct.count(:company_name)
  end

  def show
    @word_count = @cover_letter.word_count
    @read_time = @cover_letter.estimated_read_time
  end

  def new
    @cover_letter = @resume.cover_letters.build(
      target_role: @resume.target_role,
      tone: "professional",
      length: "medium"
    )
  end

  def create
    @cover_letter = @resume.cover_letters.build(cover_letter_params)
    @cover_letter.user = current_user
    @cover_letter.status = "draft"

    # Use job description from params or fall back to resume's job description
    @cover_letter.job_description = params[:job_description].presence || @resume.job_description

    if @cover_letter.save
      unless current_user.can_generate?(CreditPolicy::COVER_LETTER)
        redirect_to [ @resume, @cover_letter ], alert: "Insufficient credits. Please upgrade your plan."
        return
      end

      @cover_letter.update!(status: "generating", provider: selected_provider)

      GenerateCoverLetterJob.perform_later(@cover_letter.id, current_user.id)
      ahoy.track "cover_letter_generate", cover_letter_id: @cover_letter.id, resume_id: @resume.id

      redirect_to [ @resume, @cover_letter ], notice: "Cover letter generation started! This will take 30-45 seconds."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cover_letter.update(cover_letter_params)
      redirect_to [ @resume, @cover_letter ], notice: "Cover letter updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cover_letter.destroy
    redirect_to @resume, notice: "Cover letter deleted successfully."
  end

  def generate_variations
    count = params[:count]&.to_i || 3
    count = [ count, 5 ].min # Max 5 variations

    unless current_user.can_generate?(count * CreditPolicy::COVER_LETTER)
      redirect_to [ @resume, @cover_letter ], alert: "Insufficient credits. Please upgrade your plan."
      return
    end

    GenerateCoverLetterVariationsJob.perform_later(@cover_letter.id, current_user.id, count)

    redirect_to [ @resume, @cover_letter ], notice: "Generating #{count} variations! This will take 1-2 minutes."
  end

  def regenerate
    unless current_user.can_generate?(CreditPolicy::COVER_LETTER)
      redirect_to [ @resume, @cover_letter ], alert: "Insufficient credits. Please upgrade your plan."
      return
    end

    @cover_letter.update!(status: "generating", provider: selected_provider)
    GenerateCoverLetterJob.perform_later(@cover_letter.id, current_user.id)

    redirect_to [ @resume, @cover_letter ], notice: "Cover letter generation restarted."
  end

  def preview
    render layout: false
  end

  def download
    format = params[:format].presence || "pdf"
    filename = "#{@cover_letter.company_name.parameterize}-cover-letter"

    case format.to_s
    when "pdf"
      send_data build_pdf_document, filename: "#{filename}.pdf", type: "application/pdf", disposition: "attachment"
    when "docx"
      send_data build_docx_document, filename: "#{filename}.docx", type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", disposition: "attachment"
    when "txt"
      send_data build_cover_letter_text, filename: "#{filename}.txt", type: "text/plain", disposition: "attachment"
    else
      redirect_to [ @resume, @cover_letter ], alert: "Invalid format requested."
    end
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:resume_id]) if params[:resume_id]
  end

  def set_cover_letter
    if @resume
      @cover_letter = @resume.cover_letters.find(params[:id])
    else
      @cover_letter = current_user.cover_letters.find(params[:id])
      @resume = @cover_letter.resume
    end
  end

  def cover_letter_params
    params.require(:cover_letter).permit(
      :company_name, :hiring_manager_name, :target_role,
      :tone, :length, :content, :provider
    )
  end

  def selected_provider
    provider = params[:provider].presence || params.dig(:cover_letter, :provider).presence || @cover_letter&.provider.presence || "openai"
    provider = "openai" if provider == "anthropic" && !current_user.has_premium_subscription?
    provider
  end

  def calculate_response_rate
    # This is a placeholder - you would track actual responses
    return nil if @cover_letters.empty?
    # For now, return nil to show the dash
    nil
  end

  def build_cover_letter_text
    user_name = current_user.full_name.presence || current_user.email
    user_email = current_user.email
    user_phone = current_user.formatted_phone

    lines = []
    lines << user_name
    lines << user_email
    lines << user_phone if user_phone.present?
    lines << ""
    lines << Date.current.strftime("%B %d, %Y")
    lines << ""
    lines << @cover_letter.hiring_manager_name if @cover_letter.hiring_manager_name.present?
    lines << @cover_letter.company_name
    lines << "Re: #{@cover_letter.target_role} Position" if @cover_letter.target_role.present?
    lines << ""
    lines << @cover_letter.greeting
    lines << ""
    lines << @cover_letter.body_content
    lines << ""
    lines << "Sincerely,"
    lines << ""
    lines << user_name

    lines.join("\n")
  end

  def build_pdf_document
    require "prawn"

    user_name = current_user.full_name.presence || current_user.email
    user_email = current_user.email
    user_phone = current_user.formatted_phone
    company = @cover_letter.company_name
    manager = @cover_letter.hiring_manager_name
    role = @cover_letter.target_role
    letter_content = @cover_letter.content.to_s

    # Create PDF without block form to avoid potential recursion issues
    pdf = Prawn::Document.new(page_size: "LETTER")

    # Header with user info
    pdf.text user_name, size: 16, style: :bold
    pdf.text user_email, size: 12
    pdf.text user_phone, size: 12 if user_phone.present?
    pdf.move_down 20

    # Date
    pdf.text Date.current.strftime("%B %d, %Y"), size: 12
    pdf.move_down 20

    # Recipient info
    pdf.text manager, size: 12 if manager.present?
    pdf.text company, size: 12, style: :bold
    pdf.text "Re: #{role} Position", size: 12 if role.present?
    pdf.move_down 20

    # Content
    pdf.text @cover_letter.greeting, size: 12
    pdf.move_down 12
    pdf.text letter_content, size: 12, leading: 3, align: :justify if letter_content.present?

    pdf.move_down 30

    # Closing
    pdf.text "Sincerely,", size: 12
    pdf.move_down 30
    pdf.text user_name, size: 12, style: :bold

    pdf.render
  end

  def build_docx_document
    require "zip"

    paragraphs = build_cover_letter_text.split("\n").map do |line|
      escaped = line.to_s.encode(xml: :text)
      if escaped.blank?
        '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>'
      else
        "<w:p><w:pPr><w:spacing w:after=\"80\"/></w:pPr><w:r><w:rPr><w:sz w:val=\"22\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
      end
    end.join

    Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' \
                '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' \
                '<Default Extension="xml" ContentType="application/xml"/>' \
                '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' \
                "</Types>"
      zip.put_next_entry("_rels/.rels")
      zip.write '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' \
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' \
                "</Relationships>"
      zip.put_next_entry("word/document.xml")
      zip.write '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' \
                "<w:body>#{paragraphs}</w:body></w:document>"
    end.string
  end
end
