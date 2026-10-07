module ResumesHelper
  # Best-effort extraction of the "TOP 5 ACTIONABLE IMPROVEMENTS" items from
  # the ATS analysis text. Returns [] when the analysis is missing or in a
  # language where the header was translated — the full analysis text remains
  # available in the collapsible panel either way.
  def ats_improvements(analysis)
    return [] if analysis.blank?
    return [] unless analysis =~ /ACTIONABLE IMPROVEMENTS/i

    block = analysis.split(/(?:TOP\s*5\s*)?ACTIONABLE IMPROVEMENTS[:*\s]*/i).last.to_s
    block.scan(/^\s*\d+\.\s*(.+?)\s*$/).flatten
         .map { |item| item.gsub("**", "").strip }
         .reject(&:blank?)
         .first(5)
  end

  # Renders plain resume text as a typeset document: section headers,
  # bullet lists, role lines, and the name/contact block get real markup
  # instead of a <pre>. Text is reflowed first so legacy records that were
  # stored with extraction line breaks still read cleanly.
  def formatted_resume_html(text)
    return "".html_safe if text.blank?

    lines = ResumeTextReflowService.new(text).reflow.split("\n")
    html = +""
    list_open = false
    seen_header = false
    preamble_index = 0

    close_list = lambda do
      next unless list_open
      html << "</ul>"
      list_open = false
    end

    lines.each do |line|
      stripped = line.strip

      if stripped.blank?
        close_list.call
        next
      end

      if ResumeContentParserService.section_header?(stripped)
        close_list.call
        seen_header = true
        heading = stripped.gsub(/\A[#*=\-]+\s*|\s*[#*=\-]+\z|:\z/, "").gsub(/\A\*\*(.+)\*\*\z/, '\1')
        html << %(<h3 class="rt-h">#{ERB::Util.html_escape(heading)}</h3>)
      elsif stripped.match?(ResumeTextReflowService::BULLET_RE)
        unless list_open
          html << %(<ul class="rt-ul">)
          list_open = true
        end
        html << %(<li class="rt-li">#{ERB::Util.html_escape(stripped.sub(ResumeTextReflowService::BULLET_RE, ""))}</li>)
      elsif !seen_header && preamble_index == 0
        close_list.call
        html << %(<p class="rt-name">#{ERB::Util.html_escape(stripped)}</p>)
        preamble_index += 1
      elsif !seen_header
        close_list.call
        html << %(<p class="rt-contact">#{ERB::Util.html_escape(stripped)}</p>)
        preamble_index += 1
      elsif stripped.include?(" | ")
        close_list.call
        parts = stripped.split(/\s*\|\s*/).map { |p| ERB::Util.html_escape(p) }
        html << %(<p class="rt-role"><strong>#{parts.shift}</strong>)
        html << %(<span class="rt-role-meta"> · #{parts.join(' · ')}</span>) if parts.any?
        html << "</p>"
      else
        close_list.call
        html << %(<p class="rt-p">#{ERB::Util.html_escape(stripped)}</p>)
      end
    end

    close_list.call
    html.html_safe
  end

  # Inline template preview (same renderer as the Design & preview page) so
  # the resume page can show the designed document without a new tab.
  def resume_template_preview_html(resume)
    return nil unless resume.resume_sections.visible.any?

    ResumeTemplateService.new(resume: resume).render_html_preview.html_safe
  rescue StandardError => e
    Rails.logger.warn "Inline template preview failed for resume #{resume.id}: #{e.message}"
    nil
  end
end
