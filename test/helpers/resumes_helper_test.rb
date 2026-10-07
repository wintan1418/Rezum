require "test_helper"

class ResumesHelperTest < ActionView::TestCase
  include ResumesHelper

  test "renders headers, bullets, role lines and the name block as markup" do
    text = <<~TEXT
      Jane Doe
      jane@example.com | +1 555 123 4567

      PROFESSIONAL SUMMARY
      Engineer with eight years of experience shipping payments infrastructure.

      PROFESSIONAL EXPERIENCE
      Senior Engineer | Acme Corp | Jan 2020 - Present
      - Cut checkout latency 40% by rewriting the payment router.
      • Mentored <three> engineers.
    TEXT

    html = formatted_resume_html(text)

    assert_includes html, '<p class="rt-name">Jane Doe</p>'
    assert_includes html, '<p class="rt-contact">jane@example.com | +1 555 123 4567</p>'
    assert_includes html, '<h3 class="rt-h">PROFESSIONAL SUMMARY</h3>'
    assert_includes html, '<p class="rt-role"><strong>Senior Engineer</strong><span class="rt-role-meta"> · Acme Corp · Jan 2020 - Present</span></p>'
    assert_includes html, '<li class="rt-li">Cut checkout latency 40% by rewriting the payment router.</li>'
    assert_includes html, "Mentored &lt;three&gt; engineers."
    assert_equal 1, html.scan("<ul").size
    assert html.html_safe?
  end

  test "reflows legacy content stored with extraction line breaks" do
    text = "PROFILE\nOrganised professional with experience in virtual education, learner support and educational\ncoordination across teams."
    html = formatted_resume_html(text)

    assert_includes html, "educational coordination across teams."
    assert_equal 1, html.scan('<p class="rt-p">').size
  end

  test "returns empty safe string for blank content" do
    assert_equal "", formatted_resume_html(nil)
    assert formatted_resume_html("").html_safe?
  end
end
