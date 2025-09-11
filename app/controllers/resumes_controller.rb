class ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [:show, :edit, :update, :destroy, :optimize, :ats_score, :keywords, :download]
  
  def index
    @resumes = current_user.resumes.recent.includes(:cover_letters)
    @optimized_count = @resumes.optimized.count
    @total_ats_score = @resumes.optimized.average(:ats_score)&.round(1)
  end
  
  def show
    @cover_letters = @resume.cover_letters.recent.limit(5)
    @ats_analysis = @resume.ats_score.present?
  end
  
  def new
    @resume = current_user.resumes.build
  end
  
  def create
    @resume = current_user.resumes.build(resume_params)
    @resume.status = 'draft'
    
    # Handle file upload and text extraction
    if params[:resume][:file].present?
      begin
        processor = ResumeFileProcessorService.new(
          file: params[:resume][:file],
          user_id: current_user.id
        )
        
        extraction_result = processor.process
        @resume.original_content = extraction_result[:text]
        @resume.file.attach(params[:resume][:file])
        
        # Auto-detect target role from content if not provided
        if @resume.target_role.blank?
          @resume.target_role = extract_target_role_from_content(extraction_result[:text])
        end
        
      rescue ResumeProcessingError => e
        @resume.errors.add(:file, e.message)
        render :new, status: :unprocessable_entity
        return
      end
    end
    
    if @resume.save
      if @resume.file.attached?
        redirect_to @resume, notice: 'Resume uploaded and processed successfully! Ready for optimization.'
      else
        redirect_to @resume, notice: 'Resume created successfully! Ready for optimization.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @resume.update(resume_params)
      redirect_to @resume, notice: 'Resume updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: 'Resume deleted successfully.'
  end
  
  def optimize
    unless current_user.can_generate?
      redirect_to @resume, alert: 'Insufficient credits. Please upgrade your plan.'
      return
    end
    
    @resume.update!(status: 'processing', provider: params[:provider] || 'openai')
    
    OptimizeResumeJob.perform_later(@resume.id, current_user.id)
    
    redirect_to @resume, notice: 'Resume optimization started! This will take 30-60 seconds.'
  end
  
  def ats_score
    unless @resume.optimized?
      redirect_to @resume, alert: 'Please optimize your resume first to get ATS score.'
      return
    end
    
    @resume.update!(status: 'processing')
    
    AnalyzeAtsScoreJob.perform_later(@resume.id)
    
    redirect_to @resume, notice: 'ATS analysis started! Results will be available shortly.'
  end
  
  def keywords
    return unless @resume.job_description.present?
    
    service = ResumeOptimizerService.new(
      content: @resume.original_content,
      job_description: @resume.job_description,
      user_id: current_user.id,
      user_country: current_user.country_code
    )
    
    begin
      keywords = service.extract_keywords
      @keywords_array = keywords.split(',').map(&:strip)
      
      render json: { keywords: @keywords_array }
    rescue AiServiceError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  def download
    format = params[:format] || 'txt'
    content = @resume.optimized_content.present? ? @resume.optimized_content : @resume.original_content
    
    unless content.present?
      redirect_to @resume, alert: 'No content available for download.'
      return
    end
    
    filename = "#{@resume.target_role.parameterize}-resume"
    
    case format
    when 'pdf'
      pdf_data = generate_pdf(content)
      send_data pdf_data, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'
    when 'docx'
      docx_data = generate_docx(content)
      send_data docx_data, filename: "#{filename}.docx", type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', disposition: 'attachment'
    when 'txt'
      send_data content, filename: "#{filename}.txt", type: 'text/plain', disposition: 'attachment'
    else
      redirect_to @resume, alert: 'Invalid format requested.'
    end
  end
  
  private
  
  def set_resume
    @resume = current_user.resumes.find(params[:id])
  end
  
  def resume_params
    params.require(:resume).permit(
      :original_content, :job_description, :target_role, 
      :industry, :experience_level, :provider, :file
    )
  end
  
  def extract_target_role_from_content(content)
    # Simple role extraction based on common patterns
    common_roles = [
      'Software Engineer', 'Data Scientist', 'Product Manager', 'Marketing Manager',
      'Sales Representative', 'Business Analyst', 'Project Manager', 'Designer',
      'Developer', 'Consultant', 'Analyst', 'Specialist', 'Coordinator', 'Manager'
    ]
    
    # Look for role mentions in the content
    content_lower = content.downcase
    
    common_roles.find do |role|
      content_lower.include?(role.downcase)
    end || 'Professional' # Default fallback
  end
  
  def generate_pdf(content)
    require 'prawn'
    
    Prawn::Document.new do |pdf|
      pdf.font "Helvetica"
      pdf.font_size 11
      pdf.text content, align: :left, leading: 2
    end.render
  rescue => e
    Rails.logger.error "PDF generation failed: #{e.message}"
    raise "PDF generation failed: #{e.message}"
  end
  
  def generate_docx(content)
    require 'docx'
    
    # Create a new document
    doc = Docx::Document.new
    
    # Add content as paragraphs
    content.split("\n").each do |line|
      doc.p line.strip unless line.strip.empty?
    end
    
    # Return the document as binary data
    StringIO.new.tap do |stream|
      doc.save(stream)
      stream.rewind
    end.read
  rescue => e
    Rails.logger.error "DOCX generation failed: #{e.message}"
    raise "DOCX generation failed: #{e.message}"
  end
end
