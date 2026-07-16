require "test_helper"

class ScrapedJobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:taylor)
    @user.subscriptions.create!(
      paystack_subscription_code: "SUB_premium_test",
      status: "active",
      plan_id: "price_monthly_premium",
      current_period_start: 1.day.ago,
      current_period_end: 30.days.from_now
    )
    sign_in @user

    @job = @user.scraped_jobs.create!(
      company_name: "Acme Corp",
      role: "Backend Engineer",
      description: "Build Rails APIs with PostgreSQL.",
      url: "https://example.com/jobs/1",
      status: "new",
      match_score: 70
    )
  end

  test "tailor_resume creates a draft resume from latest resume with the job's description" do
    source = resumes(:optimized_resume)

    assert_difference "@user.resumes.count", 1 do
      post tailor_resume_scraped_job_path(@job)
    end

    draft = @user.resumes.order(:created_at).last
    assert_redirected_to resume_path(draft)
    assert_equal "Backend Engineer", draft.target_role
    assert_equal @job.description, draft.job_description
    assert_equal source.optimized_content, draft.original_content
    assert_equal "saved", @job.reload.status
  end

  test "tailor_resume redirects to upload when user has no resumes" do
    @user.job_applications.destroy_all
    @user.resumes.destroy_all

    post tailor_resume_scraped_job_path(@job)

    assert_redirected_to new_resume_path
  end

  test "marking a scraped job applied creates a tracker entry once" do
    assert_difference "@user.job_applications.count", 1 do
      patch scraped_job_path(@job), params: { scraped_job: { status: "applied" } }
    end

    application = @user.job_applications.last
    assert_equal "Acme Corp", application.company_name
    assert_equal "applied", application.status

    @job.update!(status: "saved")
    assert_no_difference "@user.job_applications.count" do
      patch scraped_job_path(@job), params: { scraped_job: { status: "applied" } }
    end
  end

  test "non-premium users see the feature lock instead of jobs" do
    sign_in users(:broke_user)

    get scraped_jobs_path

    assert_response :success
    assert_match(/premium/i, response.body)
    assert_no_match(/Acme Corp/, response.body)
  end
end
