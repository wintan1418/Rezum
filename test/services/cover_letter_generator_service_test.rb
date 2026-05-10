require "test_helper"

class CoverLetterGeneratorServiceTest < ActiveSupport::TestCase
  test "job description is optional" do
    service = CoverLetterGeneratorService.new(
      resume_content: "Experienced software engineer. " * 10,
      company_name: "Acme",
      target_role: "Software Engineer",
      tone: "professional",
      length: "short",
      provider: "openai"
    )

    assert service.valid?
  end

  test "generate honors selected provider and returns body only" do
    captured = nil
    service = CoverLetterGeneratorService.new(
      resume_content: "Experienced product manager. " * 10,
      company_name: "Acme",
      target_role: "Product Manager",
      tone: "enthusiastic",
      length: "short",
      provider: "google"
    )
    service.define_singleton_method(:generate_completion) do |**kwargs|
      captured = kwargs
      "Dear Hiring Manager,\n\nI am excited to bring product leadership to Acme.\n\nSincerely,\nTaylor"
    end

    content = service.generate

    assert_equal :google, captured[:provider]
    assert_no_match(/Dear Hiring Manager/i, content)
    assert_no_match(/Sincerely/i, content)
    assert_match(/product leadership/, content)
  end
end
