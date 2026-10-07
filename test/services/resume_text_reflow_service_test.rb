require "test_helper"

class ResumeTextReflowServiceTest < ActiveSupport::TestCase
  # Mirrors the layout pdf-reader produces for a two-column resume: one line
  # per visual line, skills grid read across the page.
  EXTRACTED = <<~TEXT
    SEYI ANOINTED
    CLASS ADMINISTRATION | LEARNER SUPPORT | VIRTUAL EDUCATION
    +234 810 434 1676 | Seyianointed01@gmail.com | Nigeria

    PROFILE
    Organised, detail-oriented and proactive professional with experience in virtual education, learner support and educational
    coordination. Currently leads the development of Eternity MedVirtual and supports students preparing for academic and
    professional examinations.

    CORE SKILLS
    • Learner & Online Class Support • Written Communication
    • Documentation & Reporting • Attention to Detail

    RELEVANT EXPERIENCE
    Steward & Project Lead - Eternity MedVirtual
    Developing Virtual Medical & Health Sciences Education Initiative
    • Leads the ongoing development of a virtual medical and health sciences education initiative, coordinating learner-focused
    educational support across different academic levels.
    • Guides the organisation and development of educational content.

    EDUCATION
    B.Sc. Medical Laboratory Science
    University of Medical Sciences (UNIMED), Ondo, Ondo State, Nigeria
  TEXT

  setup do
    @reflowed = ResumeTextReflowService.new(EXTRACTED).reflow
    @lines = @reflowed.split("\n")
  end

  test "rejoins sentences wrapped mid-line" do
    profile = @lines[@lines.index("PROFILE") + 1]
    assert_includes profile, "educational coordination. Currently leads"
    assert_includes profile, "academic and professional examinations."
    assert_equal "CORE SKILLS", @lines[@lines.index("PROFILE") + 3]
  end

  test "splits two-column bullet grids into one bullet per line" do
    assert_includes @lines, "- Learner & Online Class Support"
    assert_includes @lines, "- Written Communication"
    assert_includes @lines, "- Documentation & Reporting"
    assert_includes @lines, "- Attention to Detail"
    assert_not @reflowed.include?("Support - Written")
  end

  test "rejoins a bullet wrapped onto a second line" do
    assert_includes @lines, "- Leads the ongoing development of a virtual medical and health sciences education initiative, coordinating learner-focused educational support across different academic levels."
  end

  test "keeps headers, names, contact and short lines standalone" do
    assert_equal "SEYI ANOINTED", @lines.first
    assert_includes @lines, "CLASS ADMINISTRATION | LEARNER SUPPORT | VIRTUAL EDUCATION"
    assert_includes @lines, "+234 810 434 1676 | Seyianointed01@gmail.com | Nigeria"
    assert_includes @lines, "RELEVANT EXPERIENCE"
    assert_includes @lines, "Steward & Project Lead - Eternity MedVirtual"
    assert_includes @lines, "B.Sc. Medical Laboratory Science"
  end

  test "does not join title, company and date stacks" do
    text = "EXPERIENCE\nSenior Software Engineer\nTechCorp Inc. | San Francisco, CA | Jan 2022 - Present\n- Led migration of the platform\nSoftware Engineer\nStartupXYZ\nMar 2019 - Dec 2021"
    lines = ResumeTextReflowService.new(text).reflow.split("\n")
    assert_equal [ "EXPERIENCE", "Senior Software Engineer", "TechCorp Inc. | San Francisco, CA | Jan 2022 - Present", "- Led migration of the platform", "Software Engineer", "StartupXYZ", "Mar 2019 - Dec 2021" ], lines
  end

  test "is idempotent" do
    assert_equal @reflowed, ResumeTextReflowService.new(@reflowed).reflow
  end

  test "collapses runs of blank lines and handles blank input" do
    assert_equal "A line here.\n\nAnother line.", ResumeTextReflowService.new("A line here.\n\n\n\nAnother line.").reflow
    assert_equal "", ResumeTextReflowService.new(nil).reflow
  end
end
