require "test_helper"

class JobScraperServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:taylor)
    @settings = @user.create_job_scraper_setting!(
      target_roles: [ "Backend Engineer" ],
      keywords: [ "Ruby on Rails", "PostgreSQL" ],
      remote_only: true,
      enabled: true
    )
    @service = JobScraperService.new(user: @user, settings: @settings)
  end

  test "skill profile combines resume skills, matched keywords, and settings keywords" do
    resume = @user.resumes.create!(
      original_content: "X" * 150,
      target_role: "Backend Engineer",
      status: "draft",
      keyword_match_data: {
        "keywords" => [], "missing" => [],
        "matched" => [ { "term" => "Sidekiq", "category" => "required_hard_skills", "count" => 2 } ],
        "match_rate" => 50
      }
    )
    resume.resume_sections.create!(
      section_type: "skills",
      content: { "items" => [ "Redis", "Docker" ] },
      position: 0
    )

    profile = @service.send(:build_skill_profile)

    assert_includes profile, "Redis"
    assert_includes profile, "Sidekiq"
    assert_includes profile, "Ruby on Rails"
  end

  test "scores concrete skill hits with role and remote bonuses" do
    job = {
      role: "Senior Backend Engineer",
      description: "We use Ruby on Rails and PostgreSQL daily.",
      remote: true
    }

    score = @service.send(:calculate_match_score, job, [ "Ruby on Rails", "PostgreSQL", "Kubernetes" ])

    # 2 skill hits (30) + role bonus (15) + remote bonus (10)
    assert_equal 55, score
  end

  test "generic words no longer inflate scores" do
    job = {
      role: "Marketing Director",
      description: "Great team with experience in management and communication across projects.",
      remote: false
    }

    score = @service.send(:calculate_match_score, job, [ "Ruby on Rails", "PostgreSQL" ])

    assert_equal 0, score, "no concrete skill hits, no role match -> zero"
  end

  test "falls back to neutral score with empty profile" do
    job = { role: "Engineer", description: "Anything", remote: false }

    assert_equal 50, @service.send(:calculate_match_score, job, [])
  end
end
