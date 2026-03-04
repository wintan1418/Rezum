class ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [ :show, :edit, :update, :destroy, :optimize, :ats_score, :keywords, :download ]

  def index
    @resumes = current_user.resumes.recent.includes(:cover_letters)
    @optimized_count = @resumes.optimized.count
    @total_ats_score = @resumes.optimized.average(:ats_score)&.round(1)
  end

  def show
    if @resume.expires_at.present? && !current_user.has_premium_subscription?
      redirect_to preview_resume_wizard_path(@resume) and return
    end

    @cover_letters = @resume.cover_letters.recent.limit(5)
    @ats_analysis = @resume.ats_score.present?

    if @resume.optimized? && @resume.optimized_content.present?
      @diff_html = ResumeDiffService.new(
        original: @resume.original_content,
        optimized: @resume.optimized_content
      ).generate_html_diff
    end
  end

  def new
    @resume = current_user.resumes.build
  end

  def create
    @resume = current_user.resumes.build(resume_params)
    @resume.status = "draft"

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
      ahoy.track "resume_upload", resume_id: @resume.id
      if @resume.file.attached?
        redirect_to @resume, notice: "Resume uploaded and processed successfully! Ready for optimization."
      else
        redirect_to @resume, notice: "Resume created successfully! Ready for optimization."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @resume.update(resume_params)
      redirect_to @resume, notice: "Resume updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: "Resume deleted successfully."
  end

  def optimize
    unless current_user.can_generate?
      redirect_to @resume, alert: "Insufficient credits. Please upgrade your plan."
      return
    end

    if @resume.original_content.blank?
      redirect_to edit_resume_path(@resume), alert: "Your resume has no content to optimize."
      return
    end

    selected_provider = params[:provider] || "openai"

    # Anthropic Claude is Premium-only
    if selected_provider == "anthropic" && !current_user.has_premium_subscription?
      selected_provider = "openai"
    end

    @resume.update!(status: "processing", provider: selected_provider)
    ahoy.track "resume_optimize", resume_id: @resume.id, provider: @resume.provider

    OptimizeResumeJob.perform_later(@resume.id, current_user.id)

    redirect_to @resume, notice: "Resume optimization started! This will take 30-60 seconds."
  end

  def ats_score
    unless @resume.optimized?
      redirect_to @resume, alert: "Please optimize your resume first to get ATS score."
      return
    end

    @resume.update!(status: "processing")

    AnalyzeAtsScoreJob.perform_later(@resume.id)

    redirect_to @resume, notice: "ATS analysis started! Results will be available shortly."
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
      @keywords_array = keywords.split(",").map(&:strip)

      render json: { keywords: @keywords_array }
    rescue AiServiceError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def download
    if @resume.expires_at.present? && !current_user.has_premium_subscription?
      redirect_to preview_resume_wizard_path(@resume), alert: "Upgrade to Premium to download this resume." and return
    end

    format = params[:format] || "txt"
    content = @resume.optimized_content.present? ? @resume.optimized_content : @resume.original_content

    unless content.present?
      redirect_to @resume, alert: "No content available for download."
      return
    end

    filename = "#{@resume.target_role.parameterize}-resume-#{@resume.template || 'professional'}"
    has_sections = @resume.resume_sections.visible.any?

    case format
    when "pdf"
      if has_sections
        # Use template service for formatted PDF with sections
        service = ResumeTemplateService.new(resume: @resume)
        pdf_data = service.render_pdf
      else
        pdf_data = generate_pdf(content)
      end
      send_data pdf_data, filename: "#{filename}.pdf", type: "application/pdf", disposition: "attachment"
    when "docx"
      if has_sections
        docx_data = generate_docx_from_sections
      else
        docx_data = generate_docx(content)
      end
      send_data docx_data, filename: "#{filename}.docx", type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", disposition: "attachment"
    when "txt"
      send_data content, filename: "#{filename}.txt", type: "text/plain", disposition: "attachment"
    else
      redirect_to @resume, alert: "Invalid format requested."
    end
  end

  def import_linkedin
    unless current_user.can_generate?
      redirect_to new_resume_path, alert: "Insufficient credits. Please upgrade your plan to import from LinkedIn."
      return
    end

    linkedin_text = nil

    # Option 1: PDF file upload (primary method)
    if params[:linkedin_pdf].present?
      begin
        file = params[:linkedin_pdf]
        unless file.content_type == "application/pdf"
          redirect_to new_resume_path, alert: "Please upload a PDF file."
          return
        end

        processor = ResumeFileProcessorService.new(file: file, user_id: current_user.id)
        extraction = processor.process
        linkedin_text = extraction[:text]
      rescue StandardError => e
        Rails.logger.error "LinkedIn PDF processing failed: #{e.message}"
        redirect_to new_resume_path, alert: "Failed to process PDF. Please try pasting your profile text instead."
        return
      end
    # Option 2: Paste text (fallback)
    elsif params[:linkedin_text].present?
      linkedin_text = params[:linkedin_text].to_s.strip
    end

    if linkedin_text.blank?
      redirect_to new_resume_path, alert: "Please upload your LinkedIn PDF or paste your profile text."
      return
    end

    parser = LinkedinProfileParserService.new(linkedin_text)
    result = parser.parse

    # Build clean original_content from parsed sections (not raw noisy text)
    clean_content = build_clean_resume_text(result)

    @resume = current_user.resumes.create!(
      original_content: clean_content,
      target_role: result[:headline].presence || "Professional",
      status: "processing",
      template: "professional",
      provider: "openai"
    )

    result[:sections].each do |section_data|
      @resume.resume_sections.create!(
        section_type: section_data[:section_type],
        content: section_data[:content],
        position: section_data[:position],
        visible: true
      )
    end

    # Auto-optimize the imported resume (OptimizeResumeJob handles credit deduction)
    OptimizeResumeJob.perform_later(@resume.id, current_user.id)

    ahoy.track "linkedin_import", resume_id: @resume.id
    redirect_to @resume, notice: "LinkedIn profile imported and optimization started! This will take 30-60 seconds."
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

  def build_clean_resume_text(result)
    parts = []
    parts << result[:name] if result[:name].present?
    parts << result[:headline] if result[:headline].present?
    parts << ""

    result[:sections].each do |section|
      case section[:section_type]
      when "summary"
        parts << "SUMMARY"
        parts << section[:content]["text"]
      when "experience"
        parts << "EXPERIENCE"
        section[:content]["entries"].each do |entry|
          parts << "#{entry['title']} | #{entry['company']} | #{entry['dates']}"
          Array(entry["bullets"]).each { |b| parts << "- #{b}" }
        end
      when "education"
        parts << "EDUCATION"
        section[:content]["entries"].each do |entry|
          parts << "#{entry['degree']} | #{entry['school']} | #{entry['dates']}"
          parts << entry["details"] if entry["details"].present?
        end
      when "skills"
        parts << "SKILLS"
        parts << section[:content]["items"].join(", ")
      when "certifications"
        parts << "CERTIFICATIONS"
        section[:content]["items"].each { |item| parts << "- #{item}" }
      when "languages"
        parts << "LANGUAGES"
        section[:content]["items"].each { |item| parts << "- #{item}" }
      end
      parts << ""
    end

    parts.join("\n").strip
  end

  def extract_target_role_from_content(content)
    # Simple role extraction based on common patterns
    common_roles = [
      "Software Engineer", "Data Scientist", "Product Manager", "Marketing Manager",
      "Sales Representative", "Business Analyst", "Project Manager", "Designer",
      "Developer", "Consultant", "Analyst", "Specialist", "Coordinator", "Manager"
    ]

    # Look for role mentions in the content
    content_lower = content.downcase

    common_roles.find do |role|
      content_lower.include?(role.downcase)
    end || "Professional" # Default fallback
  end

  def generate_docx_from_sections
    require "zip"

    sections = @resume.resume_sections.visible.ordered
    paragraphs = []

    # Header: Name and role
    name = @resume.optimized_content&.lines&.first&.strip.presence || @resume.target_role
    paragraphs << docx_heading(name, 28, center: true)
    paragraphs << docx_subtitle(@resume.target_role, center: true)
    contact = [ current_user.email, current_user.try(:formatted_phone) ].compact.join(" | ")
    paragraphs << docx_small_text(contact, center: true) if contact.present?
    paragraphs << docx_spacer

    sections.each do |section|
      data = section.content_data
      paragraphs << docx_heading(section.section_label.upcase, 24)

      case section.section_type
      when "summary"
        paragraphs << docx_body_text(data["text"].to_s)
      when "experience"
        Array(data["entries"]).each do |entry|
          title_line = [ entry["title"], entry["dates"] ].reject(&:blank?).join("  |  ")
          paragraphs << docx_bold_text(title_line)
          paragraphs << docx_italic_text(entry["company"].to_s) if entry["company"].present?
          Array(entry["bullets"]).each { |b| paragraphs << docx_bullet(b) }
          paragraphs << docx_spacer
        end
      when "education"
        Array(data["entries"]).each do |entry|
          degree_line = [ entry["degree"], entry["dates"] ].reject(&:blank?).join("  |  ")
          paragraphs << docx_bold_text(degree_line)
          paragraphs << docx_italic_text(entry["school"].to_s) if entry["school"].present?
          paragraphs << docx_body_text(entry["details"].to_s) if entry["details"].present?
          paragraphs << docx_spacer
        end
      when "skills"
        paragraphs << docx_body_text(Array(data["items"]).join(", "))
      when "certifications", "awards", "languages"
        Array(data["items"]).each { |item| paragraphs << docx_bullet(item) }
      when "projects"
        Array(data["entries"]).each do |entry|
          paragraphs << docx_bold_text(entry["name"].to_s)
          paragraphs << docx_body_text(entry["description"].to_s)
          paragraphs << docx_spacer
        end
      end
      paragraphs << docx_spacer
    end

    xml_body = paragraphs.join

    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write docx_content_types
      zip.put_next_entry("_rels/.rels")
      zip.write docx_rels
      zip.put_next_entry("word/_rels/document.xml.rels")
      zip.write docx_document_rels
      zip.put_next_entry("word/document.xml")
      zip.write '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' \
                "<w:body>#{xml_body}</w:body></w:document>"
      zip.put_next_entry("word/styles.xml")
      zip.write docx_styles
    end
    buffer.string
  end

  def docx_heading(text, size, center: false)
    escaped = text.to_s.encode(xml: :text)
    align = center ? '<w:jc w:val="center"/>' : ""
    "<w:p><w:pPr><w:spacing w:after=\"80\"/>#{align}</w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"#{size}\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_subtitle(text, center: false)
    escaped = text.to_s.encode(xml: :text)
    align = center ? '<w:jc w:val="center"/>' : ""
    "<w:p><w:pPr><w:spacing w:after=\"40\"/>#{align}</w:pPr><w:r><w:rPr><w:sz w:val=\"22\"/><w:color w:val=\"666666\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_small_text(text, center: false)
    escaped = text.to_s.encode(xml: :text)
    align = center ? '<w:jc w:val="center"/>' : ""
    "<w:p><w:pPr><w:spacing w:after=\"40\"/>#{align}</w:pPr><w:r><w:rPr><w:sz w:val=\"18\"/><w:color w:val=\"999999\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_bold_text(text)
    escaped = text.to_s.encode(xml: :text)
    "<w:p><w:pPr><w:spacing w:after=\"20\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"22\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_italic_text(text)
    escaped = text.to_s.encode(xml: :text)
    "<w:p><w:pPr><w:spacing w:after=\"20\"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val=\"22\"/><w:color w:val=\"444444\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_body_text(text)
    escaped = text.to_s.encode(xml: :text)
    "<w:p><w:pPr><w:spacing w:after=\"40\"/></w:pPr><w:r><w:rPr><w:sz w:val=\"22\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
  end

  def docx_bullet(text)
    escaped = text.to_s.encode(xml: :text)
    "<w:p><w:pPr><w:spacing w:after=\"20\"/><w:ind w:left=\"360\"/></w:pPr><w:r><w:rPr><w:sz w:val=\"22\"/></w:rPr><w:t xml:space=\"preserve\">\u2022 #{escaped}</w:t></w:r></w:p>"
  end

  def docx_spacer
    '<w:p><w:pPr><w:spacing w:after="60"/></w:pPr></w:p>'
  end

  def generate_pdf(content)
    require "prawn"

    Prawn::Document.new do |pdf|
      pdf.font "Helvetica"
      pdf.font_size 11
      pdf.text content, align: :left, leading: 2
    end.render
  rescue StandardError => e
    Rails.logger.error "PDF generation failed: #{e.message}"
    raise "PDF generation failed: #{e.message}"
  end

  def generate_docx(content)
    require "zip"

    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write docx_content_types

      zip.put_next_entry("_rels/.rels")
      zip.write docx_rels

      zip.put_next_entry("word/_rels/document.xml.rels")
      zip.write docx_document_rels

      zip.put_next_entry("word/document.xml")
      zip.write docx_document_xml(content)

      zip.put_next_entry("word/styles.xml")
      zip.write docx_styles
    end

    buffer.string
  rescue StandardError => e
    Rails.logger.error "DOCX generation failed: #{e.message}"
    raise "DOCX generation failed: #{e.message}"
  end

  def docx_content_types
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' \
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' \
    '<Default Extension="xml" ContentType="application/xml"/>' \
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' \
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>' \
    "</Types>"
  end

  def docx_rels
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' \
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' \
    "</Relationships>"
  end

  def docx_document_rels
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' \
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' \
    "</Relationships>"
  end

  def docx_document_xml(content)
    paragraphs = content.split("\n").map do |line|
      text = line.strip
      next if text.empty?

      escaped = text.encode(xml: :text)
      # Make lines that look like section headers bold
      if text == text.upcase && text.length > 2 && text.length < 60
        "<w:p><w:pPr><w:spacing w:after=\"120\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"24\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
      else
        "<w:p><w:pPr><w:spacing w:after=\"40\"/></w:pPr><w:r><w:rPr><w:sz w:val=\"22\"/></w:rPr><w:t xml:space=\"preserve\">#{escaped}</w:t></w:r></w:p>"
      end
    end.compact.join

    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' \
    "<w:body>" + paragraphs + "</w:body></w:document>"
  end

  def docx_styles
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' \
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">' \
    '<w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr>' \
    "</w:style></w:styles>"
  end
end
