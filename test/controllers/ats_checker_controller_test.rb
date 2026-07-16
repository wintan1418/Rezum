require "test_helper"

class AtsCheckerControllerTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  test "check enqueues background job instead of calling AI inline" do
    resume_text = <<~TEXT
      John Doe
      john@example.com | +1 555 0100 | New York

      EXPERIENCE
      Senior Software Engineer at Acme Corporation, January 2020 - Present
      - Built and maintained high-traffic backend systems in Ruby on Rails serving millions of requests
      - Reduced PostgreSQL query latency by 60 percent through targeted indexing and query optimization

      EDUCATION
      BSc Computer Science, State University, 2012-2016

      SKILLS
      Ruby on Rails, PostgreSQL, Redis, Docker, AWS
    TEXT
    file = Rack::Test::UploadedFile.new(
      StringIO.new(resume_text), "text/plain", original_filename: "resume.txt"
    )

    assert_enqueued_with(job: AtsCheckerJob) do
      post ats_checker_check_path, params: { resume_file: file }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match(/poll-result/, response.body)
  end

  test "result returns no_content while pending and results when ready" do
    token = SecureRandom.hex(16)

    get ats_checker_result_path(token: token)
    assert_response :no_content

    AtsCheckerJob.write_result(token, {
      overall_score: 72, format_score: 70, content_score: 74,
      strengths: [ "Clear sections" ], issues: [ "No metrics" ],
      improvements: [ "Add quantified achievements" ]
    })

    get ats_checker_result_path(token: token)
    assert_response :success
    assert_match(/72/, response.body)
  end

  test "result rejects malformed tokens" do
    get ats_checker_result_path(token: "not-a-token")
    assert_response :bad_request
  end

  test "capture_email is rate limited per IP" do
    6.times do |i|
      post "/ats-checker/capture-email", params: { email: "lead#{i}@example.com" }
    end

    assert_response :too_many_requests
  end
end
