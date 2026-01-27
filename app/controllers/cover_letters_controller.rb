class CoverLettersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, except: [:index]
  before_action :set_cover_letter, only: [:show, :edit, :update, :destroy, :generate_variations, :preview, :download]
  
  def index
    @cover_letters = current_user.cover_letters.recent.includes(:resume)
    @sent_count = @cover_letters.where(status: 'sent').count
    @response_rate = calculate_response_rate
    @companies_count = @cover_letters.pluck(:company_name).uniq.compact.count
  end
  
  def show
    @word_count = @cover_letter.word_count
    @read_time = @cover_letter.estimated_read_time
  end
  
  def new
    @cover_letter = @resume.cover_letters.build(
      target_role: @resume.target_role,
      tone: 'professional',
      length: 'medium'
    )
  end
  
  def create
    @cover_letter = @resume.cover_letters.build(cover_letter_params)
    @cover_letter.user = current_user
    @cover_letter.status = 'draft'
    
    # Use job description from params or fall back to resume's job description
    @cover_letter.job_description = params[:job_description].presence || @resume.job_description
    
    if @cover_letter.save
      unless current_user.can_generate?
        redirect_to [@resume, @cover_letter], alert: 'Insufficient credits. Please upgrade your plan.'
        return
      end
      
      @cover_letter.update!(status: 'generating', provider: params[:provider] || 'openai')
      
      GenerateCoverLetterJob.perform_later(@cover_letter.id, current_user.id)
      
      redirect_to [@resume, @cover_letter], notice: 'Cover letter generation started! This will take 30-45 seconds.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @cover_letter.update(cover_letter_params)
      redirect_to [@resume, @cover_letter], notice: 'Cover letter updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @cover_letter.destroy
    redirect_to @resume, notice: 'Cover letter deleted successfully.'
  end
  
  def generate_variations
    unless current_user.can_generate?
      redirect_to [@resume, @cover_letter], alert: 'Insufficient credits. Please upgrade your plan.'
      return
    end
    
    count = params[:count]&.to_i || 3
    count = [count, 5].min # Max 5 variations
    
    GenerateCoverLetterVariationsJob.perform_later(@cover_letter.id, current_user.id, count)
    
    redirect_to [@resume, @cover_letter], notice: "Generating #{count} variations! This will take 1-2 minutes."
  end
  
  def preview
    render layout: false
  end
  
  def download
    filename = "#{@cover_letter.company_name.parameterize}-cover-letter"
    
    respond_to do |format|
      format.pdf do
        pdf_content = generate_pdf_content
        send_data pdf_content, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'
      end
      
      format.docx do
        docx_content = generate_docx_content
        send_data docx_content, filename: "#{filename}.docx", type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', disposition: 'attachment'
      end
      
      format.txt do
        txt_content = generate_txt_content
        send_data txt_content, filename: "#{filename}.txt", type: 'text/plain', disposition: 'attachment'
      end
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
  
  def calculate_response_rate
    # This is a placeholder - you would track actual responses
    return nil if @cover_letters.empty?
    # For now, return nil to show the dash
    nil
  end
  
  def generate_pdf_content
    require 'prawn'
    
    Prawn::Document.new(page_size: 'LETTER') do |pdf|
      # Header with user info
      pdf.text current_user.full_name.present? ? current_user.full_name : current_user.email, size: 16, style: :bold
      pdf.text current_user.email, size: 12
      if current_user.formatted_phone.present?
        pdf.text current_user.formatted_phone, size: 12
      end
      pdf.move_down 20
      
      # Date
      pdf.text Date.current.strftime("%B %d, %Y"), size: 12
      pdf.move_down 20
      
      # Recipient info
      if @cover_letter.hiring_manager_name.present?
        pdf.text @cover_letter.hiring_manager_name, size: 12
      end
      pdf.text @cover_letter.company_name, size: 12, style: :bold
      if @cover_letter.target_role.present?
        pdf.text "Re: #{@cover_letter.target_role} Position", size: 12
      end
      pdf.move_down 20
      
      # Content
      if @cover_letter.content.present?
        pdf.text @cover_letter.content, size: 12, leading: 3, align: :justify
      end
      
      pdf.move_down 30
      
      # Closing
      pdf.text "Sincerely,", size: 12
      pdf.move_down 30
      pdf.text current_user.full_name.present? ? current_user.full_name : current_user.email, size: 12, style: :bold
    end.render
  end
  
  def generate_docx_content
    require 'docx'
    
    doc = Docx::Document.new
    
    # Header
    doc.p do
      text current_user.full_name.present? ? current_user.full_name : current_user.email, bold: true
      br
      text current_user.email
      if current_user.formatted_phone.present?
        br
        text current_user.formatted_phone
      end
    end
    
    doc.p
    doc.p Date.current.strftime("%B %d, %Y")
    doc.p
    
    # Recipient
    doc.p do
      if @cover_letter.hiring_manager_name.present?
        text @cover_letter.hiring_manager_name
        br
      end
      text @cover_letter.company_name, bold: true
      if @cover_letter.target_role.present?
        br
        text "Re: #{@cover_letter.target_role} Position"
      end
    end
    
    doc.p
    
    # Content
    if @cover_letter.content.present?
      @cover_letter.content.split("\n\n").each do |paragraph|
        doc.p paragraph.strip
      end
    end
    
    doc.p
    doc.p "Sincerely,"
    doc.p
    doc.p
    doc.p(current_user.full_name.present? ? current_user.full_name : current_user.email, bold: true)
    
    doc.save('temp_cover_letter.docx')
    content = File.read('temp_cover_letter.docx')
    File.delete('temp_cover_letter.docx')
    content
  end
  
  def generate_txt_content
    content = []
    
    # Header
    content << (current_user.full_name.present? ? current_user.full_name : current_user.email)
    content << current_user.email
    content << current_user.formatted_phone if current_user.formatted_phone.present?
    content << ""
    
    # Date
    content << Date.current.strftime("%B %d, %Y")
    content << ""
    
    # Recipient
    content << @cover_letter.hiring_manager_name if @cover_letter.hiring_manager_name.present?
    content << @cover_letter.company_name
    content << "Re: #{@cover_letter.target_role} Position" if @cover_letter.target_role.present?
    content << ""
    
    # Content
    if @cover_letter.content.present?
      content << @cover_letter.content
    end
    
    content << ""
    content << "Sincerely,"
    content << ""
    content << ""
    content << (current_user.full_name.present? ? current_user.full_name : current_user.email)
    
    content.join("\n")
  end
end
