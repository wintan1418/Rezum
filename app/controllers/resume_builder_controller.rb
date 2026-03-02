class ResumeBuilderController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume

  def edit
    # Auto-populate sections from resume content if none exist
    if @resume.resume_sections.empty? && @resume.original_content.present?
      auto_create_sections_from_content
    end

    @sections = @resume.resume_sections.ordered.reload
    @templates = ResumeTemplateService::TEMPLATES
    @available_types = ResumeSection::SECTION_TYPES - @sections.map(&:section_type)
  end

  def update
    if params[:resume].present?
      @resume.update(template: params[:resume][:template]) if params[:resume][:template].present?
    end

    if params[:sections].present?
      params[:sections].each do |id, section_params|
        section = @resume.resume_sections.find_by(id: id)
        next unless section

        content = parse_section_content(section.section_type, section_params[:content])
        section.update(
          content: content,
          visible: section_params[:visible] == "1",
          position: section_params[:position].to_i
        )
      end
    end

    redirect_to edit_resume_builder_path(@resume), notice: "Resume saved successfully."
  end

  def preview
    service = ResumeTemplateService.new(resume: @resume)
    @preview_html = service.render_html_preview
    render layout: false
  end

  def add_section
    position = @resume.resume_sections.maximum(:position).to_i + 1
    default_content = default_content_for(params[:section_type])

    @section = @resume.resume_sections.create!(
      section_type: params[:section_type],
      content: default_content,
      position: position
    )

    redirect_to edit_resume_builder_path(@resume), notice: "#{@section.section_label} section added."
  end

  def remove_section
    section = @resume.resume_sections.find(params[:section_id])
    section.destroy
    redirect_to edit_resume_builder_path(@resume), notice: "Section removed."
  end

  def reorder
    if params[:order].present?
      params[:order].each_with_index do |id, index|
        @resume.resume_sections.where(id: id).update_all(position: index)
      end
    end
    head :ok
  end

  def download_pdf
    service = ResumeTemplateService.new(resume: @resume)
    pdf_data = service.render_pdf
    filename = "#{@resume.target_role.parameterize}-resume-#{@resume.template}.pdf"
    send_data pdf_data, filename: filename, type: "application/pdf", disposition: "attachment"
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:resume_id])
  end

  def parse_section_content(type, raw)
    return {} unless raw
    content = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h

    case type
    when "experience"
      entries = (content["entries"] || {}).values.map do |e|
        bullets = e["bullets_text"].present? ? e["bullets_text"].split("\n").map(&:strip).reject(&:blank?) : Array(e["bullets"])
        { "title" => e["title"], "company" => e["company"], "dates" => e["dates"], "bullets" => bullets }
      end
      { "entries" => entries }
    when "education"
      entries = (content["entries"] || {}).values.map do |e|
        { "degree" => e["degree"], "school" => e["school"], "dates" => e["dates"], "details" => e["details"] }
      end
      { "entries" => entries }
    when "skills"
      items = content["items_text"].present? ? content["items_text"].split(",").map(&:strip).reject(&:blank?) : Array(content["items"])
      { "items" => items }
    when "certifications", "awards", "languages"
      items = content["items_text"].present? ? content["items_text"].split("\n").map(&:strip).reject(&:blank?) : Array(content["items"])
      { "items" => items }
    when "projects"
      entries = (content["entries"] || {}).values.map do |e|
        { "name" => e["name"], "description" => e["description"] }
      end
      { "entries" => entries }
    when "summary"
      { "text" => content["text"] }
    else
      content
    end
  end

  def default_content_for(type)
    case type
    when "summary"
      { "text" => "" }
    when "experience"
      { "entries" => [ { "title" => "", "company" => "", "dates" => "", "bullets" => [ "" ] } ] }
    when "education"
      { "entries" => [ { "degree" => "", "school" => "", "dates" => "", "details" => "" } ] }
    when "skills"
      { "items" => [] }
    when "certifications", "awards", "languages"
      { "items" => [] }
    when "projects"
      { "entries" => [ { "name" => "", "description" => "" } ] }
    else
      {}
    end
  end

  def auto_create_sections_from_content
    content = @resume.optimized_content.presence || @resume.original_content
    parser = ResumeContentParserService.new(content)
    parsed = parser.parse

    parsed.each do |section_data|
      @resume.resume_sections.create!(
        section_type: section_data[:section_type],
        content: section_data[:content],
        position: section_data[:position],
        visible: true
      )
    end
  rescue => e
    Rails.logger.warn "Auto-parsing resume content failed: #{e.message}"
  end
end
