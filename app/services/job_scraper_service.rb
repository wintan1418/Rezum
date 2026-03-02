class JobScraperService
  SERPAPI_BASE_URL = 'https://serpapi.com/search.json'

  def initialize(user:, settings: nil)
    @user = user
    @settings = settings || user.job_scraper_setting
    @api_key = ENV['SERPAPI_API_KEY']
  end

  def scrape
    return { success: false, error: 'No SerpAPI key configured' } if @api_key.blank?
    return { success: false, error: 'No scraper settings found' } unless @settings

    all_jobs = []

    # Build search queries from settings and user's resume data
    queries = build_search_queries
    queries.each do |query|
      results = search_google_jobs(query)
      all_jobs.concat(results) if results.any?
    end

    # Deduplicate by external_id or url
    all_jobs.uniq! { |j| j[:external_id] || j[:url] }

    # Score jobs against user's resume
    scored_jobs = score_jobs(all_jobs)

    # Save new jobs (skip duplicates)
    saved_count = save_jobs(scored_jobs)

    # Update last scraped timestamp
    @settings.update!(last_scraped_at: Time.current)

    { success: true, found: all_jobs.size, saved: saved_count }
  rescue => e
    Rails.logger.error "Job scraping failed for user #{@user.id}: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def build_search_queries
    queries = []

    roles = @settings.target_roles_list
    locations = @settings.target_locations_list

    # If no roles configured, try to extract from user's resumes
    if roles.empty?
      roles = @user.resumes.pluck(:target_role).compact.uniq.first(3)
    end

    # Default fallback
    roles = ['Software Engineer'] if roles.empty?

    if locations.any?
      roles.each do |role|
        locations.each do |location|
          query = role.dup
          query += " #{@settings.keywords_list.first(3).join(' ')}" if @settings.keywords_list.any?
          queries << { q: query, location: location }
        end
      end
    else
      roles.each do |role|
        query = role.dup
        query += " #{@settings.keywords_list.first(3).join(' ')}" if @settings.keywords_list.any?
        queries << { q: query }
      end
    end

    queries.first(5) # Limit API calls
  end

  def search_google_jobs(query)
    params = {
      engine: 'google_jobs',
      q: query[:q],
      api_key: @api_key,
      num: @settings.max_results_per_scrape || 20
    }
    params[:location] = query[:location] if query[:location].present?

    uri = URI(SERPAPI_BASE_URL)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    jobs_results = data['jobs_results'] || []

    jobs_results.map do |job|
      {
        company_name: job['company_name'] || 'Unknown',
        role: job['title'] || query[:q],
        location: job['location'] || query[:location],
        description: job['description'],
        url: extract_apply_link(job),
        source: 'google_jobs',
        job_type: detect_job_type(job),
        remote: detect_remote(job),
        salary_range: extract_salary(job),
        tags: extract_tags(job),
        external_id: job['job_id'],
        expires_at: parse_expiry(job)
      }
    end
  rescue => e
    Rails.logger.error "SerpAPI search failed: #{e.message}"
    []
  end

  def extract_apply_link(job)
    apply_options = job['apply_options'] || job['related_links'] || []
    if apply_options.is_a?(Array) && apply_options.any?
      apply_options.first['link']
    else
      job['share_link'] || job['related_links']&.first
    end
  end

  def detect_job_type(job)
    extensions = (job['detected_extensions'] || {})
    schedule = extensions['schedule_type'] || ''
    case schedule.downcase
    when /full.?time/ then 'full_time'
    when /part.?time/ then 'part_time'
    when /contract/ then 'contract'
    when /intern/ then 'internship'
    else 'full_time'
    end
  end

  def detect_remote(job)
    location = (job['location'] || '').downcase
    title = (job['title'] || '').downcase
    description = (job['description'] || '').downcase.first(500)
    location.include?('remote') || title.include?('remote') || description.include?('fully remote')
  end

  def extract_salary(job)
    extensions = job['detected_extensions'] || {}
    extensions['salary'] || nil
  end

  def extract_tags(job)
    extensions = job['detected_extensions'] || {}
    tags = []
    tags << extensions['schedule_type'] if extensions['schedule_type']
    tags << extensions['work_from_home'] if extensions['work_from_home']
    tags << 'Remote' if detect_remote(job)
    highlights = job['job_highlights'] || []
    highlights.each do |h|
      tags << h['title'] if h['title']
    end
    tags.compact.uniq.first(5)
  end

  def parse_expiry(job)
    extensions = job['detected_extensions'] || {}
    posted_at = extensions['posted_at']
    return nil unless posted_at
    # Most jobs expire ~30 days after posting
    30.days.from_now
  end

  def score_jobs(jobs)
    resume_content = @user.resumes.order(updated_at: :desc).first&.original_content || ''
    resume_keywords = extract_resume_keywords(resume_content)

    jobs.map do |job|
      score = calculate_match_score(job, resume_keywords)
      job[:match_score] = score
      job
    end.sort_by { |j| -(j[:match_score] || 0) }
  end

  def extract_resume_keywords(content)
    return [] if content.blank?
    # Extract meaningful words (4+ chars, not common words)
    stop_words = %w[this that with from have been will would could should about their which through between before after during]
    content.downcase.scan(/[a-z]{4,}/).uniq
      .reject { |w| stop_words.include?(w) }
      .first(100)
  end

  def calculate_match_score(job, resume_keywords)
    return 50 if resume_keywords.empty?

    job_text = "#{job[:role]} #{job[:description]} #{job[:company_name]}".downcase
    job_words = job_text.scan(/[a-z]{4,}/).uniq

    return 50 if job_words.empty?

    matching = (resume_keywords & job_words).size
    total = [resume_keywords.size, job_words.size].min
    raw_score = (matching.to_f / total * 100).round

    # Bonus for role match
    target_roles = @settings&.target_roles_list || []
    role_bonus = target_roles.any? { |r| job[:role]&.downcase&.include?(r.downcase) } ? 15 : 0

    # Bonus for remote preference match
    remote_bonus = (@settings&.remote_only? && job[:remote]) ? 10 : 0

    [raw_score + role_bonus + remote_bonus, 100].min
  end

  def save_jobs(jobs)
    saved = 0
    jobs.each do |job_data|
      # Skip if already exists
      next if job_data[:external_id].present? &&
              @user.scraped_jobs.exists?(external_id: job_data[:external_id])
      next if job_data[:url].present? &&
              @user.scraped_jobs.exists?(url: job_data[:url])

      @user.scraped_jobs.create!(
        company_name: job_data[:company_name],
        role: job_data[:role],
        location: job_data[:location],
        salary_range: job_data[:salary_range],
        url: job_data[:url],
        description: job_data[:description],
        source: job_data[:source],
        job_type: job_data[:job_type],
        remote: job_data[:remote] || false,
        match_score: job_data[:match_score] || 50,
        status: 'new',
        tags: job_data[:tags] || [],
        external_id: job_data[:external_id],
        expires_at: job_data[:expires_at]
      )
      saved += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Skipping scraped job: #{e.message}"
    end
    saved
  end
end
