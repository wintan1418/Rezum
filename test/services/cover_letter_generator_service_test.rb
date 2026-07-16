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
    captured = []
    service = CoverLetterGeneratorService.new(
      resume_content: "Experienced product manager. " * 10,
      company_name: "Acme",
      target_role: "Product Manager",
      tone: "enthusiastic",
      length: "short",
      provider: "google"
    )
    service.define_singleton_method(:generate_completion) do |**kwargs|
      captured << kwargs
      if kwargs[:json]
        # Grounding-guard verification call: report no violations
        '{"unsupported_claims": []}'
      else
        "Dear Hiring Manager,\n\nI am excited to bring product leadership to Acme.\n\nSincerely,\nTaylor"
      end
    end

    content = service.generate

    # First call is the letter generation; the guard's verification call follows
    assert_equal :google, captured.first[:provider]
    assert_no_match(/Dear Hiring Manager/i, content)
    assert_no_match(/Sincerely/i, content)
    assert_match(/product leadership/, content)
  end
end
