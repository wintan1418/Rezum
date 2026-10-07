require "test_helper"

class ResumeContentParserServiceTest < ActiveSupport::TestCase
  # Header set from QA ticket 54: qualified headers ("Core", "Relevant") and
  # a tools section previously parsed into nothing / a bogus degree.
  TESTER_RESUME = <<~TEXT
    SEYI ANOINTED
    +234 810 434 1676 | Seyianointed01@gmail.com | Nigeria

    PROFILE
    Organised and proactive professional with experience in virtual education, learner support and educational coordination.

    CORE SKILLS
    - Learner & Online Class Support
    - Written Communication
    - Documentation & Reporting

    RELEVANT EXPERIENCE
    Steward & Project Lead - Eternity MedVirtual
    Developing Virtual Medical & Health Sciences Education Initiative
    - Leads the ongoing development of a virtual medical and health sciences education initiative.
    - Guides the organisation and development of educational content.

    EDUCATION
    B.Sc. Medical Laboratory Science
    University of Medical Sciences (UNIMED), Ondo, Ondo State, Nigeria

    DIGITAL TOOLS
    Google Classroom | WhatsApp | Email | ChatGPT | Claude | Google Gemini | Arena AI
  TEXT

  test "recognises qualified and tools headers" do
    assert_equal "summary", ResumeContentParserService.section_type_for("PROFILE")
    assert_equal "skills", ResumeContentParserService.section_type_for("CORE SKILLS")
    assert_equal "skills", ResumeContentParserService.section_type_for("Key Skills:")
    assert_equal "experience", ResumeContentParserService.section_type_for("RELEVANT EXPERIENCE")
    assert_equal "experience", ResumeContentParserService.section_type_for("## Professional Experience")
    assert_equal "skills", ResumeContentParserService.section_type_for("DIGITAL TOOLS")
    assert_equal "skills", ResumeContentParserService.section_type_for("Tech Stack")
    assert_equal "projects", ResumeContentParserService.section_type_for("Selected Projects")
    assert_nil ResumeContentParserService.section_type_for("Led the migration of a large platform to Kubernetes over 2 years")
    assert ResumeContentParserService.section_header?("EDUCATION")
    assert_not ResumeContentParserService.section_header?("- Written Communication")
  end

  test "parses the tester's resume into summary, skills, experience and education" do
    sections = ResumeContentParserService.new(TESTER_RESUME).parse
    types = sections.map { |s| s[:section_type] }

    assert_equal %w[summary skills experience education], types
    assert_equal (0..3).to_a, sections.map { |s| s[:position] }
  end

  test "merges a second skills-type section instead of filing it under education" do
    sections = ResumeContentParserService.new(TESTER_RESUME).parse
    skills = sections.find { |s| s[:section_type] == "skills" }[:content]["items"]
    education = sections.find { |s| s[:section_type] == "education" }[:content]["entries"]

    assert_includes skills, "Learner & Online Class Support"
    assert_includes skills, "Google Classroom"
    assert_includes skills, "Arena AI"
    assert_equal 1, education.size
    assert_equal "B.Sc. Medical Laboratory Science", education.first["degree"]
    assert_equal "University of Medical Sciences (UNIMED), Ondo, Ondo State, Nigeria", education.first["school"]
  end

  test "experience block keeps title and bullets" do
    sections = ResumeContentParserService.new(TESTER_RESUME).parse
    entry = sections.find { |s| s[:section_type] == "experience" }[:content]["entries"].first

    assert_equal "Steward & Project Lead - Eternity MedVirtual", entry["title"]
    assert_equal 2, entry["bullets"].count { |b| b.start_with?("Leads", "Guides") }
  end

  test "parses the optimizer's canonical pipe role line" do
    text = <<~TEXT
      PROFESSIONAL EXPERIENCE
      Senior Software Engineer | TechCorp Inc. | Jan 2022 - Present
      - Led migration of a monolith to microservices, cutting deploy time 60%.
      - Mentored four engineers.

      Software Engineer | StartupXYZ | Mar 2019 - Dec 2021
      - Built a customer dashboard used by 10,000 monthly users.
    TEXT

    entries = ResumeContentParserService.new(text).parse.first[:content]["entries"]
    assert_equal 2, entries.size
    assert_equal "Senior Software Engineer", entries[0]["title"]
    assert_equal "TechCorp Inc.", entries[0]["company"]
    assert_equal "Jan 2022 - Present", entries[0]["dates"]
    assert_equal 2, entries[0]["bullets"].size
    assert_equal "StartupXYZ", entries[1]["company"]
    assert_equal "Mar 2019 - Dec 2021", entries[1]["dates"]
  end

  test "still parses the stacked title, company-with-dates format" do
    text = <<~TEXT
      EXPERIENCE
      Senior Software Engineer
      TechCorp Inc. | San Francisco, CA | Jan 2022 - Present
      - Led migration of a monolith to microservices.
    TEXT

    entry = ResumeContentParserService.new(text).parse.first[:content]["entries"].first
    assert_equal "Senior Software Engineer", entry["title"]
    assert_includes entry["company"], "TechCorp"
    assert_includes entry["dates"], "2022"
  end
end
