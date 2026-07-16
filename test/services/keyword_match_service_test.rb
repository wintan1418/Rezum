require "test_helper"

class KeywordMatchServiceTest < ActiveSupport::TestCase
  RESUME = <<~TEXT.freeze
    Senior Software Engineer with 8 years building Ruby on Rails applications.
    Skills: Ruby on Rails, PostgreSQL, C++, .NET, Search Engine Optimization
    Led a team of 5 engineers. AWS Certified Solutions Architect.
    Ruby on Rails expert focused on scalability.
  TEXT

  test "matches keywords with occurrence counts" do
    result = KeywordMatchService.new(
      resume_text: RESUME,
      keywords: [
        { term: "Ruby on Rails", category: "required_hard_skills" },
        { term: "PostgreSQL", category: "required_hard_skills" },
        { term: "Kubernetes", category: "required_hard_skills" }
      ]
    ).match

    rails = result[:matched].find { |e| e[:term] == "Ruby on Rails" }
    assert_equal 3, rails[:count]
    assert_equal [ "Kubernetes" ], result[:missing].map { |e| e[:term] }
  end

  test "matching is case-insensitive and word-bounded" do
    result = KeywordMatchService.new(
      resume_text: "Expert in java and JavaScript development",
      keywords: [
        { term: "Java", category: "required_hard_skills" },
        { term: "JavaScript", category: "required_hard_skills" }
      ]
    ).match

    java = result[:matched].find { |e| e[:term] == "Java" }
    # "JavaScript" must not count as an occurrence of "Java"
    assert_equal 1, java[:count]
  end

  test "handles symbol-heavy terms like C++ and .NET" do
    result = KeywordMatchService.new(
      resume_text: RESUME,
      keywords: [
        { term: "C++", category: "required_hard_skills" },
        { term: ".NET", category: "required_hard_skills" }
      ]
    ).match

    assert_empty result[:missing]
    assert_equal 100, result[:match_rate]
  end

  test "acronym pairs match on either form" do
    result = KeywordMatchService.new(
      resume_text: RESUME,
      keywords: [ { term: "Search Engine Optimization (SEO)", category: "domain_expertise" } ]
    ).match

    assert_equal 1, result[:matched].size
  end

  test "match rate weights required skills heavier than soft skills" do
    # matched: 1 soft skill (weight 1); missing: 1 required skill (weight 3)
    result = KeywordMatchService.new(
      resume_text: "Strong communication",
      keywords: [
        { term: "communication", category: "soft_skills" },
        { term: "Terraform", category: "required_hard_skills" }
      ]
    ).match

    assert_equal 25, result[:match_rate]
  end

  test "accepts string keys and skips blank terms" do
    result = KeywordMatchService.new(
      resume_text: RESUME,
      keywords: [ { "term" => "PostgreSQL", "category" => "required_hard_skills" }, { term: "", category: "soft_skills" } ]
    ).match

    assert_equal 1, result[:matched].size
    assert_empty result[:missing]
  end

  test "returns zero match rate for empty keywords" do
    result = KeywordMatchService.new(resume_text: RESUME, keywords: []).match

    assert_equal 0, result[:match_rate]
    assert_empty result[:matched]
  end
end
