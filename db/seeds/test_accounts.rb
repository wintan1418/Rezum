# Test accounts for development — run with: rails db:seed
# All passwords: "password123"

puts "Seeding test accounts..."

PASSWORD = "password123"

# ============================================================
# Sample resume content for testing
# ============================================================
SAMPLE_RESUME = <<~RESUME
  PROFESSIONAL SUMMARY
  Results-driven Software Engineer with 6+ years of experience building scalable web applications. Proficient in Ruby on Rails, React, PostgreSQL, and cloud infrastructure. Proven track record of delivering high-impact features, improving system performance by 40%, and mentoring junior developers.

  EXPERIENCE
  Senior Software Engineer
  TechCorp Inc. | San Francisco, CA | Jan 2022 - Present
  - Led migration of monolithic Rails app to microservices architecture, reducing deployment time by 60%
  - Built real-time notification system serving 500K+ users using ActionCable and Redis
  - Mentored team of 4 junior engineers through code reviews and pair programming sessions
  - Implemented CI/CD pipeline with GitHub Actions, reducing release cycle from 2 weeks to 2 days

  Software Engineer
  StartupXYZ | New York, NY | Mar 2019 - Dec 2021
  - Developed customer-facing dashboard used by 10,000+ monthly active users
  - Optimized database queries reducing average response time from 800ms to 120ms
  - Integrated Stripe payment system processing $2M+ in annual transactions
  - Built automated testing suite achieving 95% code coverage

  Junior Developer
  WebAgency Co. | Austin, TX | Jun 2017 - Feb 2019
  - Built responsive web applications for 15+ client projects using Rails and React
  - Collaborated with design team to implement pixel-perfect UI components
  - Maintained and improved legacy PHP applications during migration to Rails

  EDUCATION
  B.S. Computer Science
  University of Texas at Austin | 2013 - 2017
  GPA: 3.7, Dean's List, Computer Science Honor Society

  SKILLS
  Ruby on Rails, React, TypeScript, PostgreSQL, Redis, Docker, AWS, Git, CI/CD, REST APIs, GraphQL, Agile/Scrum

  CERTIFICATIONS
  AWS Solutions Architect Associate - 2023
  Ruby on Rails Professional Certificate - 2021
RESUME

SAMPLE_JOB_DESCRIPTION = <<~JD
  Senior Full-Stack Engineer at InnovateTech

  We're looking for a Senior Full-Stack Engineer to join our growing team. You'll work on building and scaling our SaaS platform used by thousands of businesses worldwide.

  Requirements:
  - 5+ years of experience with Ruby on Rails and modern JavaScript frameworks (React preferred)
  - Strong experience with PostgreSQL and Redis
  - Experience with cloud services (AWS, GCP, or Azure)
  - Familiarity with CI/CD pipelines and DevOps practices
  - Experience with microservices architecture
  - Strong communication skills and ability to mentor junior team members
  - BS in Computer Science or equivalent experience

  Nice to have:
  - Experience with TypeScript and GraphQL
  - Knowledge of Docker and Kubernetes
  - Open source contributions
  - Experience in a SaaS environment

  We offer competitive salary ($150K-$200K), equity, remote-friendly culture, and generous PTO.
JD

# ============================================================
# Helper to create user + subscription
# ============================================================
def create_test_user(attrs)
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(
    password: PASSWORD,
    password_confirmation: PASSWORD,
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    confirmed_at: Time.current,
    credits_remaining: attrs[:credits] || 3,
    onboarding_completed: true,
    onboarding_step: 3,
    language: 'en',
    country_code: attrs[:country_code] || 'US',
    job_title: attrs[:job_title],
    industry: attrs[:industry],
    experience_level: attrs[:experience_level],
    last_active_at: Time.current,
    marketing_consent: true
  )

  # Skip referral code generation on save if already set
  user.save!
  puts "  Created user: #{user.email} (#{attrs[:role]})"
  user
end

def create_subscription(user, plan_id:, status: 'active')
  sub = user.subscriptions.find_or_initialize_by(
    paystack_subscription_code: "sub_test_#{user.id}_#{plan_id}"
  )
  sub.assign_attributes(
    plan_id: plan_id,
    status: status,
    current_period_start: 1.month.ago,
    current_period_end: 11.months.from_now
  )
  sub.save!
  user.update!(subscription_status: status == 'canceled' ? :cancelled : :active)
  puts "    + Subscription: #{sub.plan_name} (#{status})"
  sub
end

def create_resume(user, optimized: false)
  resume = user.resumes.find_or_initialize_by(target_role: 'Senior Software Engineer')
  resume.assign_attributes(
    original_content: SAMPLE_RESUME,
    job_description: SAMPLE_JOB_DESCRIPTION,
    industry: 'technology',
    experience_level: 'senior',
    status: optimized ? 'optimized' : 'draft',
    optimized_content: optimized ? "#{SAMPLE_RESUME}\n\n[AI-OPTIMIZED: Keywords enhanced, ATS score improved]" : nil,
    ats_score: optimized ? 87 : nil,
    keywords: optimized ? 'Ruby on Rails, React, PostgreSQL, AWS, microservices, CI/CD, TypeScript, GraphQL, Docker, SaaS' : nil
  )
  resume.save!
  puts "    + Resume: #{resume.target_role} (#{resume.status})"
  resume
end

def create_cover_letter(user, resume)
  cl = user.cover_letters.find_or_initialize_by(company_name: 'InnovateTech')
  cl.assign_attributes(
    resume: resume,
    target_role: 'Senior Full-Stack Engineer',
    job_description: SAMPLE_JOB_DESCRIPTION,
    tone: 'professional',
    length: 'medium',
    content: "Dear Hiring Manager,\n\nI am writing to express my interest in the Senior Full-Stack Engineer position at InnovateTech. With 6+ years of experience building scalable web applications using Ruby on Rails and React, I am confident I would be a strong fit for your team.\n\nAt TechCorp Inc., I led the migration of a monolithic Rails application to a microservices architecture, reducing deployment time by 60%. I also built a real-time notification system serving over 500,000 users.\n\nI am excited about InnovateTech's mission to scale your SaaS platform and would welcome the opportunity to contribute my expertise.\n\nBest regards",
    status: 'generated',
    provider: 'openai'
  )
  cl.save!
  puts "    + Cover Letter: #{cl.company_name}"
  cl
end

def create_job_applications(user, resume, cover_letter)
  apps = [
    { company_name: 'InnovateTech', role: 'Senior Full-Stack Engineer', status: 'interview', applied_at: 5.days.ago, url: 'https://example.com/jobs/1', location: 'Remote', remote: true, salary_offered: '$170K', contact_name: 'Sarah Chen', contact_email: 'sarah@innovatetech.com' },
    { company_name: 'DataFlow Inc.', role: 'Staff Engineer', status: 'applied', applied_at: 3.days.ago, url: 'https://example.com/jobs/2', location: 'San Francisco, CA', remote: false, salary_offered: '$190K' },
    { company_name: 'CloudScale', role: 'Senior Backend Engineer', status: 'phone_screen', applied_at: 7.days.ago, follow_up_at: 2.days.from_now, location: 'Remote', remote: true },
    { company_name: 'FinTech Pro', role: 'Lead Engineer', status: 'offer', applied_at: 14.days.ago, location: 'New York, NY', salary_offered: '$200K + equity' },
    { company_name: 'StartupAI', role: 'Full-Stack Developer', status: 'rejected', applied_at: 20.days.ago, location: 'Austin, TX' },
    { company_name: 'MegaCorp', role: 'Software Engineer III', status: 'wishlist', location: 'Seattle, WA', remote: true }
  ]

  apps.each do |app_data|
    ja = user.job_applications.find_or_initialize_by(company_name: app_data[:company_name], role: app_data[:role])
    ja.assign_attributes(app_data.merge(resume: resume, cover_letter: cover_letter))
    ja.save!
  end
  puts "    + #{apps.count} Job Applications"
end

def create_scraped_jobs(user)
  jobs = [
    { company_name: 'Google', role: 'Senior Software Engineer', location: 'Mountain View, CA', salary_range: '$180K - $250K', match_score: 92, url: 'https://careers.google.com/1', source: 'google_jobs', job_type: 'full_time', remote: false, description: 'Join Google Cloud team building next-gen infrastructure.', tags: [ 'Ruby', 'Go', 'Cloud' ], status: 'new' },
    { company_name: 'Stripe', role: 'Full-Stack Engineer', location: 'Remote', salary_range: '$170K - $220K', match_score: 88, url: 'https://stripe.com/jobs/1', source: 'google_jobs', job_type: 'full_time', remote: true, description: 'Build payment infrastructure powering millions of businesses.', tags: [ 'Ruby on Rails', 'React', 'PostgreSQL' ], status: 'saved' },
    { company_name: 'Shopify', role: 'Senior Rails Developer', location: 'Remote', salary_range: '$160K - $210K', match_score: 95, url: 'https://shopify.com/jobs/1', source: 'google_jobs', job_type: 'full_time', remote: true, description: 'Scale the world\'s largest Rails monolith.', tags: [ 'Ruby on Rails', 'MySQL', 'GraphQL' ], status: 'new' },
    { company_name: 'GitHub', role: 'Staff Engineer', location: 'Remote', salary_range: '$190K - $260K', match_score: 85, url: 'https://github.com/jobs/1', source: 'google_jobs', job_type: 'full_time', remote: true, description: 'Build developer tools used by 100M+ developers.', tags: [ 'Ruby', 'Go', 'React' ], status: 'new' },
    { company_name: 'Airbnb', role: 'Backend Engineer', location: 'San Francisco, CA', salary_range: '$175K - $230K', match_score: 78, url: 'https://airbnb.com/jobs/1', source: 'google_jobs', job_type: 'full_time', remote: false, description: 'Build systems powering travel experiences for millions.', tags: [ 'Ruby', 'Java', 'AWS' ], status: 'applied' }
  ]

  jobs.each do |job_data|
    sj = user.scraped_jobs.find_or_initialize_by(url: job_data[:url])
    sj.assign_attributes(job_data.merge(external_id: "ext_#{Digest::MD5.hexdigest(job_data[:url])}"))
    sj.save!
  end
  puts "    + #{jobs.count} Scraped Jobs"
end

def create_job_scraper_settings(user)
  settings = user.job_scraper_setting || user.build_job_scraper_setting
  settings.assign_attributes(
    target_roles: [ 'Senior Software Engineer', 'Staff Engineer', 'Full-Stack Engineer' ],
    target_locations: [ 'Remote', 'San Francisco, CA', 'New York, NY' ],
    keywords: [ 'Ruby on Rails', 'React', 'PostgreSQL', 'AWS' ],
    min_salary: 150000,
    remote_only: false,
    auto_apply: false,
    scrape_frequency: 'daily',
    enabled: true,
    experience_level: 'senior',
    max_results_per_scrape: 20,
    last_scraped_at: 2.hours.ago
  )
  settings.save!
  puts "    + Job Scraper Settings (enabled)"
end

def create_interview_preps(user, resume)
  ip = user.interview_preps.find_or_initialize_by(company_name: 'InnovateTech')
  ip.assign_attributes(
    resume: resume,
    job_description: SAMPLE_JOB_DESCRIPTION,
    target_role: 'Senior Full-Stack Engineer',
    status: 'generated',
    provider: 'openai',
    questions: [
      { category: 'Technical', question: 'Describe your experience with microservices architecture. How did you handle service communication?', answer: 'At TechCorp, I led the migration from a monolithic Rails app to microservices using event-driven architecture with RabbitMQ...' },
      { category: 'Technical', question: 'How do you optimize database queries in PostgreSQL?', answer: 'I use EXPLAIN ANALYZE to identify bottlenecks, add appropriate indexes, use eager loading to prevent N+1 queries...' },
      { category: 'Behavioral', question: 'Tell me about a time you mentored a junior developer.', answer: 'I mentored a team of 4 junior engineers through weekly 1:1s, code reviews, and pair programming sessions...' },
      { category: 'System Design', question: 'Design a real-time notification system for 500K+ users.', answer: 'I would use ActionCable/WebSockets for real-time delivery, Redis for pub/sub, background jobs for async processing...' },
      { category: 'Behavioral', question: 'How do you handle disagreements with team members about technical decisions?', answer: 'I focus on data and trade-offs. I present benchmarks and evidence, listen to alternative approaches...' }
    ],
    company_questions: [
      { question: 'What does the tech stack look like and are there plans to evolve it?' },
      { question: 'How does the engineering team handle on-call and incident response?' },
      { question: 'What does the typical development cycle look like from idea to production?' }
    ]
  )
  ip.save!
  puts "    + Interview Prep: InnovateTech"
end

# ============================================================
# 1. FREE USER — 3 credits, no subscription
# ============================================================
puts "\n--- Free User ---"
free_user = create_test_user(
  email: 'free@test.com',
  first_name: 'Alex',
  last_name: 'Free',
  credits: 3,
  role: 'Free User',
  job_title: 'Junior Developer',
  industry: 'technology',
  experience_level: :entry,
  country_code: 'US'
)
create_resume(free_user, optimized: false)

# ============================================================
# 2. TRIAL USER — trial active, 7 days left
# ============================================================
puts "\n--- Trial User ---"
trial_user = create_test_user(
  email: 'trial@test.com',
  first_name: 'Taylor',
  last_name: 'Trial',
  credits: 10,
  role: 'Trial User',
  job_title: 'Software Engineer',
  industry: 'technology',
  experience_level: :mid,
  country_code: 'US'
)
trial_user.update!(subscription_status: :trial, trial_ends_at: 7.days.from_now)
resume = create_resume(trial_user, optimized: true)
create_cover_letter(trial_user, resume)

# ============================================================
# 3. PRO MONTHLY USER — active subscription
# ============================================================
puts "\n--- Pro Monthly User ---"
pro_monthly_user = create_test_user(
  email: 'pro@test.com',
  first_name: 'Parker',
  last_name: 'Pro',
  credits: 50,
  role: 'Pro Monthly',
  job_title: 'Senior Engineer',
  industry: 'technology',
  experience_level: :senior,
  country_code: 'US'
)
create_subscription(pro_monthly_user, plan_id: 'price_monthly_pro')
resume = create_resume(pro_monthly_user, optimized: true)
cl = create_cover_letter(pro_monthly_user, resume)
create_job_applications(pro_monthly_user, resume, cl)
create_interview_preps(pro_monthly_user, resume)

# ============================================================
# 4. PRO ANNUAL USER — active subscription
# ============================================================
puts "\n--- Pro Annual User ---"
pro_annual_user = create_test_user(
  email: 'proannual@test.com',
  first_name: 'Priya',
  last_name: 'Annual',
  credits: 100,
  role: 'Pro Annual',
  job_title: 'Tech Lead',
  industry: 'technology',
  experience_level: :senior,
  country_code: 'GB'
)
create_subscription(pro_annual_user, plan_id: 'price_annual_pro')
resume = create_resume(pro_annual_user, optimized: true)
create_cover_letter(pro_annual_user, resume)

# ============================================================
# 5. PREMIUM MONTHLY USER — full access + job scraper
# ============================================================
puts "\n--- Premium Monthly User ---"
premium_monthly_user = create_test_user(
  email: 'premium@test.com',
  first_name: 'Pam',
  last_name: 'Premium',
  credits: 200,
  role: 'Premium Monthly',
  job_title: 'Engineering Manager',
  industry: 'technology',
  experience_level: :executive,
  country_code: 'US'
)
create_subscription(premium_monthly_user, plan_id: 'price_monthly_premium')
resume = create_resume(premium_monthly_user, optimized: true)
cl = create_cover_letter(premium_monthly_user, resume)
create_job_applications(premium_monthly_user, resume, cl)
create_interview_preps(premium_monthly_user, resume)
create_scraped_jobs(premium_monthly_user)
create_job_scraper_settings(premium_monthly_user)

# ============================================================
# 6. PREMIUM ANNUAL USER — full access + job scraper
# ============================================================
puts "\n--- Premium Annual User ---"
premium_annual_user = create_test_user(
  email: 'premiumannual@test.com',
  first_name: 'Peter',
  last_name: 'Platinum',
  credits: 500,
  role: 'Premium Annual',
  job_title: 'VP of Engineering',
  industry: 'technology',
  experience_level: :executive,
  country_code: 'CA'
)
create_subscription(premium_annual_user, plan_id: 'price_annual_premium')
resume = create_resume(premium_annual_user, optimized: true)
cl = create_cover_letter(premium_annual_user, resume)
create_job_applications(premium_annual_user, resume, cl)
create_scraped_jobs(premium_annual_user)
create_job_scraper_settings(premium_annual_user)

# ============================================================
# 7. CANCELLED USER — had pro, now cancelled
# ============================================================
puts "\n--- Cancelled User ---"
cancelled_user = create_test_user(
  email: 'cancelled@test.com',
  first_name: 'Chris',
  last_name: 'Cancelled',
  credits: 0,
  role: 'Cancelled',
  job_title: 'Product Manager',
  industry: 'technology',
  experience_level: :mid,
  country_code: 'US'
)
sub = create_subscription(cancelled_user, plan_id: 'price_monthly_pro', status: 'canceled')
sub.update!(cancel_at_period_end: true, current_period_end: 5.days.from_now)
cancelled_user.update!(subscription_status: :cancelled)
create_resume(cancelled_user, optimized: true)

# ============================================================
# 8. EXHAUSTED USER — 0 credits, no subscription
# ============================================================
puts "\n--- Exhausted Credits User ---"
exhausted_user = create_test_user(
  email: 'nocredits@test.com',
  first_name: 'Nina',
  last_name: 'NoCreds',
  credits: 0,
  role: 'No Credits',
  job_title: 'UX Designer',
  industry: 'design',
  experience_level: :mid,
  country_code: 'US'
)
create_resume(exhausted_user, optimized: false)

# ============================================================
# Summary
# ============================================================
puts "\n=============================="
puts "Test Accounts Created!"
puts "=============================="
puts "All passwords: #{PASSWORD}"
puts ""
puts "  free@test.com        — Free (3 credits, no sub)"
puts "  trial@test.com       — Trial (7 days left)"
puts "  pro@test.com         — Pro Monthly ($29/mo)"
puts "  proannual@test.com   — Pro Annual ($290/yr)"
puts "  premium@test.com     — Premium Monthly ($59/mo)"
puts "  premiumannual@test.com — Premium Annual ($590/yr)"
puts "  cancelled@test.com   — Cancelled (5 days access left)"
puts "  nocredits@test.com   — No credits, no sub"
puts "=============================="
