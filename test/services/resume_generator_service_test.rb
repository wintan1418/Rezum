require "test_helper"

class ResumeGeneratorServiceTest < ActiveSupport::TestCase
  test "repairs malformed json before falling back" do
    service = ResumeGeneratorService.new(
      full_name: "Taylor Trial",
      target_role: "Software Engineer",
      experiences: [
        { "title" => "Developer", "company" => "Acme", "dates" => "2020 - Present", "description" => "Built internal tools" }
      ],
      skills: "Ruby, Rails"
    )
    service.define_singleton_method(:generate_completion) do |**_kwargs|
      <<~JSON
        [
          {"type":"summary","content":{"text":"Software Engineer with Ruby on Rails experience."}},
          {"type":"skills","content":{"items":["Ruby","Rails"]}}
        ]
      JSON
    end

    sections = service.send(:parse_ai_response, "not valid json")

    assert_equal "summary", sections.first[:type]
    assert_equal "Software Engineer with Ruby on Rails experience.", sections.first[:content]["text"]
  end
end
