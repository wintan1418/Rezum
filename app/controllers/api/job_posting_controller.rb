class Api::JobPostingController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  
  def fetch
    url = params[:url]
    
    unless valid_url?(url)
      render json: { success: false, error: 'Invalid URL provided' }, status: 400
      return
    end
    
    begin
      job_data = fetch_job_posting(url)
      
      if job_data
        render json: {
          success: true,
          job_description: job_data[:content],
          company_name: job_data[:company_name],
          job_title: job_data[:job_title],
          location: job_data[:location]
        }
      else
        render json: { success: false, error: 'Could not extract job posting content from URL' }, status: 422
      end
    rescue => e
      Rails.logger.error "Job posting fetch error: #{e.message}"
      render json: { success: false, error: 'Failed to fetch job posting. Please try copying and pasting the content manually.' }, status: 500
    end
  end
  
  private
  
  def valid_url?(url)
    return false unless url.present?
    
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
  
  def fetch_job_posting(url)
    require 'net/http'
    require 'uri'
    require 'nokogiri'
    
    uri = URI(url)
    
    # Set up HTTP client with proper headers
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.read_timeout = 10
    http.open_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (compatible; ReZum Job Parser)'
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    
    response = http.request(request)
    
    return nil unless response.is_a?(Net::HTTPSuccess)
    
    doc = Nokogiri::HTML(response.body)
    
    # Extract content based on common job posting patterns
    job_content = extract_job_content(doc, url)
    
    return nil unless job_content.present?
    
    # Parse the content using our existing service
    parser = JobPostingParserService.new(content: job_content)
    parsed_data = parser.parse
    
    {
      content: job_content,
      company_name: parsed_data[:company_name],
      job_title: parsed_data[:job_title],
      location: parsed_data[:location]
    }
  rescue Net::TimeoutError, Net::OpenTimeout
    Rails.logger.error "Timeout fetching job posting: #{url}"
    nil
  rescue => e
    Rails.logger.error "Error fetching job posting: #{e.message}"
    nil
  end
  
  def extract_job_content(doc, url)
    # Remove unwanted elements
    doc.css('script, style, nav, header, footer, .navigation, .menu, .sidebar').remove
    
    content = nil
    
    # Try different extraction strategies based on the domain
    case url
    when /linkedin\.com/
      content = extract_linkedin_content(doc)
    when /indeed\.com/
      content = extract_indeed_content(doc)
    when /glassdoor\.com/
      content = extract_glassdoor_content(doc)
    else
      content = extract_generic_content(doc)
    end
    
    # Clean up the content
    content&.gsub(/\s+/, ' ')&.strip
  end
  
  def extract_linkedin_content(doc)
    # LinkedIn specific selectors
    selectors = [
      '.jobs-description-content__text',
      '.jobs-box__html-content',
      '.job-description',
      '[data-testid="job-description"]'
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      return element.text if element
    end
    
    nil
  end
  
  def extract_indeed_content(doc)
    # Indeed specific selectors
    selectors = [
      '#jobDescriptionText',
      '.jobsearch-jobDescriptionText',
      '.job-description'
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      return element.text if element
    end
    
    nil
  end
  
  def extract_glassdoor_content(doc)
    # Glassdoor specific selectors
    selectors = [
      '.jobDescriptionContent',
      '[data-test="jobDescription"]',
      '.job-description'
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      return element.text if element
    end
    
    nil
  end
  
  def extract_generic_content(doc)
    # Generic extraction strategies
    selectors = [
      '[class*="job-description"]',
      '[class*="job_description"]',
      '[class*="description"]',
      '[id*="job-description"]',
      '[id*="description"]',
      'main',
      '.content',
      'article'
    ]
    
    selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip
        # Look for substantial content (more than 200 characters)
        return text if text.length > 200 && text.downcase.include?('job') || text.downcase.include?('position')
      end
    end
    
    # Last resort: get all paragraph text
    paragraphs = doc.css('p').map(&:text).join("\n\n")
    paragraphs.length > 200 ? paragraphs : nil
  end
end