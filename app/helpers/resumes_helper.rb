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
end
