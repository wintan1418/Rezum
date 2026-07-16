class ResumeTemplateService
  TEMPLATES = %w[professional modern minimal creative executive].freeze
  FREE_TEMPLATES = %w[professional modern].freeze

  TEMPLATE_META = {
    "professional" => { label: "Professional", color: "#1f2937", accent: "#2563eb", description: "Classic, clean layout trusted by recruiters", tier: "free" },
    "modern" => { label: "Modern", color: "#0f172a", accent: "#6366f1", description: "Contemporary design with color accents", tier: "free" },
    "minimal" => { label: "Minimal", color: "#111827", accent: "#059669", description: "Clean and simple — content first", tier: "pro" },
    "creative" => { label: "Creative", color: "#1e1b4b", accent: "#7c3aed", description: "Bold style with personality", tier: "pro" },
    "executive" => { label: "Executive", color: "#0c0a09", accent: "#b45309", description: "Sophisticated, senior-level presence", tier: "pro" }
  }.freeze

  def self.accessible_templates(user)
    user.has_paid_subscription? ? TEMPLATES : FREE_TEMPLATES
  end

  def self.template_locked?(template, user)
    !accessible_templates(user).include?(template)
  end

  attr_reader :resume, :sections, :template

  def initialize(resume:)
    @resume = resume
    @sections = resume.resume_sections.visible.ordered
    @template = resume.template || "professional"
  end

  def render_pdf
    require "prawn"

    Prawn::Document.new(page_size: "LETTER", margin: [ 50, 50, 50, 50 ]) do |pdf|
      # Serif templates preview in Georgia; Times-Roman is the PDF equivalent
      pdf.font "Times-Roman" if %w[professional executive].include?(template)
      send("render_#{template}_pdf", pdf)
    end.render
  rescue => e
    Rails.logger.error "PDF rendering failed: #{e.message}"
    raise "PDF generation failed: #{e.message}"
  end

  def render_html_preview
    meta = TEMPLATE_META[template] || TEMPLATE_META["professional"]
    send("render_#{template}_html", meta)
  end

  private

  def user
    resume.user
  end

  # The candidate's display name: first short line of the resume, falling
  # back to the account name (never recurses — a long first line previously
  # caused infinite recursion and a crashed preview).
  def resume_name
    content = resume.optimized_content.presence || resume.original_content
    first_line = content.to_s.lines.map(&:strip).find(&:present?)

    if first_line.present? && first_line.length <= 60
      first_line
    else
      user.full_name.presence || resume.target_role
    end
  end

  def contact_parts
    [ user.email, user.formatted_phone ].compact
  end

  # ==================== HTML TEMPLATES ====================

  def render_professional_html(meta)
    <<~HTML
      <div style="font-family: 'Georgia', 'Times New Roman', serif; color: #{meta[:color]}; line-height: 1.5;">
        <div style="text-align: center; margin-bottom: 20px; padding-bottom: 16px; border-bottom: 2px solid #{meta[:accent]};">
          <h1 style="font-size: 26px; font-weight: 700; margin: 0 0 4px 0; letter-spacing: 1px;">#{h resume_name}</h1>
          <p style="font-size: 15px; color: #4b5563; margin: 0 0 6px 0;">#{h resume.target_role}</p>
          <p style="font-size: 12px; color: #6b7280; margin: 0;">#{contact_parts.map { |c| h(c) }.join(' &nbsp;|&nbsp; ')}</p>
        </div>
        #{sections.map { |s| render_professional_section_html(s, meta) }.join}
      </div>
    HTML
  end

  def render_professional_section_html(section, meta)
    data = section.content_data
    heading = <<~HTML
      <div style="margin-bottom: 6px; border-bottom: 1px solid #d1d5db; padding-bottom: 3px;">
        <h2 style="font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; color: #{meta[:accent]}; margin: 0;">#{h section.section_label}</h2>
      </div>
    HTML

    content = render_section_content_html(section, data)
    "<div style='margin-bottom: 18px;'>#{heading}#{content}</div>"
  end

  def render_modern_html(meta)
    <<~HTML
      <div style="font-family: -apple-system, 'Segoe UI', Roboto, sans-serif; color: #{meta[:color]}; line-height: 1.6;">
        <div style="margin-bottom: 24px;">
          <h1 style="font-size: 30px; font-weight: 800; margin: 0 0 2px 0; color: #{meta[:accent]};">#{h resume_name}</h1>
          <p style="font-size: 16px; color: #64748b; margin: 0 0 8px 0; font-weight: 500;">#{h resume.target_role}</p>
          <div style="display: flex; gap: 16px; flex-wrap: wrap;">
            #{contact_parts.map { |c| "<span style='font-size: 12px; color: #94a3b8; display: inline-flex; align-items: center;'>#{h c}</span>" }.join("<span style='color: #cbd5e1; font-size: 12px;'>&bull;</span>")}
          </div>
        </div>
        #{sections.map { |s| render_modern_section_html(s, meta) }.join}
      </div>
    HTML
  end

  def render_modern_section_html(section, meta)
    data = section.content_data
    heading = <<~HTML
      <div style="margin-bottom: 8px; display: flex; align-items: center; gap: 8px;">
        <div style="width: 4px; height: 18px; background: #{meta[:accent]}; border-radius: 2px;"></div>
        <h2 style="font-size: 14px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #{meta[:accent]}; margin: 0;">#{h section.section_label}</h2>
      </div>
    HTML

    content = render_section_content_html(section, data)
    "<div style='margin-bottom: 20px;'>#{heading}#{content}</div>"
  end

  def render_minimal_html(meta)
    <<~HTML
      <div style="font-family: 'Helvetica Neue', Arial, sans-serif; color: #{meta[:color]}; line-height: 1.6;">
        <div style="margin-bottom: 20px;">
          <h1 style="font-size: 24px; font-weight: 600; margin: 0 0 2px 0;">#{h resume_name}</h1>
          <p style="font-size: 13px; color: #6b7280; margin: 0;">#{h resume.target_role} &nbsp;&mdash;&nbsp; #{contact_parts.map { |c| h(c) }.join(' &nbsp;|&nbsp; ')}</p>
        </div>
        #{sections.map { |s| render_minimal_section_html(s, meta) }.join}
      </div>
    HTML
  end

  def render_minimal_section_html(section, meta)
    data = section.content_data
    heading = <<~HTML
      <h2 style="font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px; color: #{meta[:accent]}; margin: 0 0 8px 0; padding-bottom: 4px; border-bottom: 1px solid #e5e7eb;">#{h section.section_label}</h2>
    HTML

    content = render_section_content_html(section, data)
    "<div style='margin-bottom: 16px;'>#{heading}#{content}</div>"
  end

  def render_creative_html(meta)
    <<~HTML
      <div style="font-family: -apple-system, 'Segoe UI', sans-serif; color: #{meta[:color]}; line-height: 1.6;">
        <div style="margin-bottom: 24px; padding: 20px 24px; background: linear-gradient(135deg, #ede9fe, #fce7f3); border-radius: 12px;">
          <h1 style="font-size: 28px; font-weight: 800; margin: 0 0 4px 0; color: #{meta[:accent]};">#{h resume_name}</h1>
          <p style="font-size: 15px; color: #6b21a8; margin: 0 0 8px 0; font-weight: 600;">#{h resume.target_role}</p>
          <p style="font-size: 12px; color: #7e22ce; margin: 0;">#{contact_parts.map { |c| h(c) }.join(' &nbsp;&bull;&nbsp; ')}</p>
        </div>
        #{sections.map { |s| render_creative_section_html(s, meta) }.join}
      </div>
    HTML
  end

  def render_creative_section_html(section, meta)
    data = section.content_data
    heading = <<~HTML
      <div style="margin-bottom: 8px;">
        <h2 style="font-size: 14px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; margin: 0; background: linear-gradient(90deg, #{meta[:accent]}, #ec4899); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">#{h section.section_label}</h2>
      </div>
    HTML

    content = render_section_content_html(section, data)
    "<div style='margin-bottom: 20px;'>#{heading}#{content}</div>"
  end

  def render_executive_html(meta)
    <<~HTML
      <div style="font-family: 'Georgia', 'Times New Roman', serif; color: #{meta[:color]}; line-height: 1.6;">
        <div style="text-align: center; margin-bottom: 24px; padding-bottom: 12px; border-bottom: 3px double #{meta[:accent]};">
          <h1 style="font-size: 28px; font-weight: 700; margin: 0 0 4px 0; letter-spacing: 3px; text-transform: uppercase;">#{h resume_name}</h1>
          <p style="font-size: 14px; color: #{meta[:accent]}; margin: 0 0 8px 0; font-weight: 600; letter-spacing: 1px;">#{h resume.target_role}</p>
          <p style="font-size: 11px; color: #78716c; margin: 0; letter-spacing: 0.5px;">#{contact_parts.map { |c| h(c) }.join(' &nbsp;&bull;&nbsp; ')}</p>
        </div>
        #{sections.map { |s| render_executive_section_html(s, meta) }.join}
      </div>
    HTML
  end

  def render_executive_section_html(section, meta)
    data = section.content_data
    heading = <<~HTML
      <div style="margin-bottom: 6px; border-bottom: 1px solid #{meta[:accent]}; padding-bottom: 2px;">
        <h2 style="font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 2px; color: #{meta[:accent]}; margin: 0;">#{h section.section_label}</h2>
      </div>
    HTML

    content = render_section_content_html(section, data)
    "<div style='margin-bottom: 20px;'>#{heading}#{content}</div>"
  end

  # ==================== SHARED SECTION CONTENT HTML ====================

  def render_section_content_html(section, data)
    case section.section_type
    when "summary"
      "<p style='font-size: 13px; color: #374151; margin: 4px 0 0 0;'>#{h data['text']}</p>"
    when "experience"
      entries = Array(data["entries"]).map do |e|
        bullets = Array(e["bullets"]).map { |b| "<li style='font-size: 13px; color: #4b5563; margin-bottom: 3px;'>#{h b}</li>" }.join
        <<~HTML
          <div style="margin-bottom: 14px;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap;">
              <p style="font-size: 14px; font-weight: 700; color: #111827; margin: 0;">#{h e['title']}</p>
              <span style="font-size: 12px; font-weight: 600; color: #374151; white-space: nowrap;">#{h e['dates']}</span>
            </div>
            <p style="font-size: 13px; font-weight: 500; color: #4b5563; margin: 1px 0 4px 0;">#{h e['company']}</p>
            #{"<ul style='padding-left: 18px; margin: 4px 0 0 0;'>#{bullets}</ul>" if bullets.present?}
          </div>
        HTML
      end.join
      entries
    when "education"
      entries = Array(data["entries"]).map do |e|
        <<~HTML
          <div style="margin-bottom: 10px;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap;">
              <p style="font-size: 14px; font-weight: 700; color: #111827; margin: 0;">#{h e['degree']}</p>
              <span style="font-size: 12px; font-weight: 600; color: #374151;">#{h e['dates']}</span>
            </div>
            <p style="font-size: 13px; font-weight: 500; color: #4b5563; margin: 1px 0 0 0;">#{h e['school']}</p>
            #{"<p style='font-size: 12px; color: #4b5563; margin: 4px 0 0 0;'>#{h e['details']}</p>" if e['details'].present?}
          </div>
        HTML
      end.join
      entries
    when "skills"
      items = Array(data["items"])
      if items.any?
        tags = items.map { |i| "<span style='display: inline-block; padding: 3px 10px; margin: 2px 4px 2px 0; background: #f3f4f6; border-radius: 4px; font-size: 12px; color: #374151;'>#{h i}</span>" }.join
        "<div style='margin-top: 4px;'>#{tags}</div>"
      else
        ""
      end
    when "projects"
      entries = Array(data["entries"]).map do |e|
        <<~HTML
          <div style="margin-bottom: 8px;">
            <p style="font-size: 14px; font-weight: 600; color: #111827; margin: 0;">#{h e['name']}</p>
            <p style="font-size: 13px; color: #4b5563; margin: 2px 0 0 0;">#{h e['description']}</p>
          </div>
        HTML
      end.join
      entries
    when "certifications", "awards", "languages"
      items = Array(data["items"]).map { |i| "<li style='font-size: 13px; color: #4b5563; margin-bottom: 2px;'>#{h i}</li>" }.join
      items.present? ? "<ul style='padding-left: 18px; margin: 4px 0 0 0;'>#{items}</ul>" : ""
    else
      "<p style='font-size: 13px; color: #4b5563;'>#{h data['text']}</p>"
    end
  end

  # ==================== PDF TEMPLATES ====================

  def render_professional_pdf(pdf)
    pdf.text resume_name, size: 24, style: :bold, align: :center
    pdf.text resume.target_role, size: 14, align: :center, color: "555555"
    contact = contact_parts.join(" | ")
    pdf.text contact, size: 10, align: :center, color: "888888"
    pdf.move_down 10
    pdf_rule(pdf, "2563EB")
    pdf.move_down 15
    sections.each { |s| render_section_pdf(pdf, s, heading_color: "2563EB", heading_rule: "D1D5DB") }
  end

  def render_modern_pdf(pdf)
    pdf.text resume_name, size: 28, style: :bold, color: "6366F1"
    pdf.text resume.target_role, size: 14, color: "6B7280"
    pdf.move_down 5
    contact = contact_parts.join("  •  ")
    pdf.text contact, size: 9, color: "9CA3AF"
    pdf.move_down 20
    sections.each { |s| render_section_pdf(pdf, s, heading_color: "6366F1", heading_rule: "6366F1") }
  end

  def render_minimal_pdf(pdf)
    pdf.text resume_name, size: 20, style: :bold
    pdf.text "#{resume.target_role}  —  #{contact_parts.join(' | ')}", size: 10, color: "6B7280"
    pdf.move_down 15
    sections.each { |s| render_section_pdf(pdf, s, heading_color: "059669", heading_rule: "E5E7EB") }
  end

  def render_creative_pdf(pdf)
    pdf.text resume_name, size: 26, style: :bold, color: "7C3AED"
    pdf.text resume.target_role, size: 14, color: "8B5CF6"
    pdf.move_down 5
    contact = contact_parts.join("  •  ")
    pdf.text contact, size: 9, color: "6B7280"
    pdf.move_down 20
    sections.each { |s| render_section_pdf(pdf, s, heading_color: "7C3AED") }
  end

  def render_executive_pdf(pdf)
    pdf.text resume_name.upcase, size: 22, style: :bold, character_spacing: 2, align: :center
    pdf.move_down 5
    pdf.text resume.target_role, size: 12, align: :center, color: "444444"
    contact = contact_parts.join("  •  ")
    pdf.text contact, size: 9, align: :center, color: "888888"
    pdf.move_down 10
    pdf_rule(pdf, "B45309")
    pdf.move_down 2
    pdf_rule(pdf, "B45309")
    pdf.move_down 15
    sections.each { |s| render_section_pdf(pdf, s, heading_color: "B45309", heading_rule: "B45309") }
  end

  # ==================== SHARED PDF SECTION RENDERING ====================

  def render_section_pdf(pdf, section, heading_color: "000000", heading_rule: nil)
    data = section.content_data

    pdf.text section.section_label.upcase, size: 12, style: :bold, color: heading_color
    if heading_rule
      pdf.move_down 2
      pdf_rule(pdf, heading_rule, width: 0.5)
    end
    pdf.move_down 6

    case section.section_type
    when "summary"
      pdf.text data["text"].to_s, size: 10, leading: 2, color: "333333"
    when "experience"
      Array(data["entries"]).each do |entry|
        # Title left, dates right-aligned \u2014 matches the on-screen preview
        pdf_entry_header(pdf, entry["title"], entry["dates"])
        pdf.text entry["company"].to_s, size: 10, style: :bold_italic, color: "444444" if entry["company"].present?
        pdf.move_down 2
        Array(entry["bullets"]).each do |bullet|
          pdf.text "  \u2022 #{bullet}", size: 10, leading: 2, color: "333333"
        end
        pdf.move_down 8
      end
    when "education"
      Array(data["entries"]).each do |entry|
        pdf_entry_header(pdf, entry["degree"], entry["dates"])
        pdf.text entry["school"].to_s, size: 10, style: :italic, color: "444444" if entry["school"].present?
        pdf.text entry["details"].to_s, size: 10, color: "333333" if entry["details"].present?
        pdf.move_down 8
      end
    when "skills"
      skills = Array(data["items"]).join("  \u2022  ")
      pdf.text skills, size: 10, leading: 3, color: "333333" if skills.present?
    when "certifications", "awards", "languages"
      Array(data["items"]).each do |item|
        pdf.text "  \u2022 #{item}", size: 10, color: "333333"
      end
    when "projects"
      Array(data["entries"]).each do |entry|
        pdf.text entry["name"].to_s, size: 11, style: :bold
        pdf.text entry["description"].to_s, size: 10, color: "333333"
        pdf.move_down 5
      end
    end

    pdf.move_down 12
  end

  # Two-column entry header: bold title on the left, dates right-aligned in
  # muted gray \u2014 mirrors the HTML preview layout.
  def pdf_entry_header(pdf, left, right)
    left = left.to_s
    right = right.to_s
    y = pdf.cursor
    dates_width = 130

    pdf.text_box left, at: [ 0, y ], width: pdf.bounds.width - dates_width - 8, height: 14,
                       size: 11, style: :bold, overflow: :shrink_to_fit
    if right.present?
      pdf.text_box right, at: [ pdf.bounds.width - dates_width, y ], width: dates_width, height: 12,
                          size: 9, style: :bold, align: :right, color: "6B7280"
    end
    pdf.move_down 15
  end

  def pdf_rule(pdf, color, width: 1)
    pdf.stroke_color color
    pdf.line_width width
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.line_width 1
  end

  def h(text)
    ERB::Util.html_escape(text.to_s)
  end
end
