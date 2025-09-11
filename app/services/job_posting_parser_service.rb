class JobPostingParserService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :content, :string
  attribute :url, :string
  attribute :user_id, :integer
  
  validates :content, presence: true, length: { minimum: 50 }
  
  def initialize(attributes = {})
    super
    @parsed_data = {}
  end
  
  def parse
    validate!
    
    @parsed_data = {
      company_name: extract_company_name,
      job_title: extract_job_title,
      location: extract_location,
      employment_type: extract_employment_type,
      experience_level: extract_experience_level,
      salary_range: extract_salary_range,
      required_skills: extract_required_skills,
      preferred_qualifications: extract_preferred_qualifications,
      benefits: extract_benefits,
      industry: extract_industry,
      remote_work: detect_remote_work,
      application_deadline: extract_deadline,
      cleaned_description: clean_job_description
    }
    
    @parsed_data
  end
  
  def extract_keywords
    validate!
    
    # Extract important keywords for ATS optimization
    keywords = []
    
    # Technical skills and tools
    keywords += extract_technical_keywords
    
    # Soft skills
    keywords += extract_soft_skills
    
    # Industry-specific terms
    keywords += extract_industry_keywords
    
    # Certifications and qualifications
    keywords += extract_certifications
    
    keywords.uniq.compact.reject(&:blank?)
  end
  
  def suggest_target_role
    job_title = extract_job_title
    return job_title if job_title.present?
    
    # Fallback: analyze content for role indicators
    role_indicators = [
      'engineer', 'developer', 'manager', 'analyst', 'specialist',
      'coordinator', 'director', 'lead', 'senior', 'junior',
      'associate', 'principal', 'architect', 'consultant'
    ]
    
    content_lower = content.downcase
    
    role_indicators.each do |indicator|
      if content_lower.include?(indicator)
        # Find the context around the role indicator
        sentences = content.split(/[.!?]/)
        relevant_sentence = sentences.find { |s| s.downcase.include?(indicator) }
        
        if relevant_sentence
          words = relevant_sentence.split
          indicator_index = words.find_index { |w| w.downcase.include?(indicator) }
          
          if indicator_index
            # Extract 2-3 words around the indicator
            start_idx = [indicator_index - 1, 0].max
            end_idx = [indicator_index + 2, words.length - 1].min
            
            potential_role = words[start_idx..end_idx].join(' ').strip
            return potential_role.titleize if potential_role.length > 5
          end
        end
      end
    end
    
    'Professional' # Default fallback
  end
  
  private
  
  def extract_company_name
    # Look for common company name patterns
    company_patterns = [
      /(?:company|corporation|corp|inc|llc|ltd|limited)[\s:]+([^\n\r.!?]+)/i,
      /(?:we are|join|about)[\s\w]*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/,
      /([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(?:is|seeks|looking)/
    ]
    
    company_patterns.each do |pattern|
      match = content.match(pattern)
      return match[1].strip if match && match[1].length > 2 && match[1].length < 50
    end
    
    nil
  end
  
  def extract_job_title
    # Look for job title patterns
    title_patterns = [
      /(?:position|role|job|title)[\s:]*([^\n\r.!?]+)/i,
      /(?:seeking|hiring|looking for)[\s\w]*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/,
      /^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*[-–—]\s*/m
    ]
    
    title_patterns.each do |pattern|
      match = content.match(pattern)
      return match[1].strip if match && match[1].length > 5 && match[1].length < 100
    end
    
    nil
  end
  
  def extract_location
    # Look for location patterns
    location_patterns = [
      /(?:location|based in|located in)[\s:]*([^\n\r.!?]+)/i,
      /([A-Z][a-z]+,\s*[A-Z]{2}(?:\s+\d{5})?)/,
      /(remote|work from home|hybrid|on-site)/i
    ]
    
    location_patterns.each do |pattern|
      match = content.match(pattern)
      return match[1].strip if match && match[1].length > 2 && match[1].length < 100
    end
    
    nil
  end
  
  def extract_employment_type
    if content.match?/full[_\s-]?time/i
      'Full-time'
    elsif content.match?/part[_\s-]?time/i
      'Part-time'
    elsif content.match?/contract/i
      'Contract'
    elsif content.match?/freelance/i
      'Freelance'
    elsif content.match?/intern/i
      'Internship'
    else
      nil
    end
  end
  
  def extract_experience_level
    if content.match?/entry[_\s-]?level|junior|0-2\s*years?/i
      'entry'
    elsif content.match?/senior|5\+?\s*years?|experienced/i
      'senior'
    elsif content.match?/lead|principal|architect|director/i
      'executive'
    elsif content.match?/mid[_\s-]?level|3-5\s*years?/i
      'mid'
    else
      nil
    end
  end
  
  def extract_salary_range
    salary_patterns = [
      /\$\s*([\d,]+(?:\.\d{2})?)\s*[-–—to]\s*\$?\s*([\d,]+(?:\.\d{2})?)/,
      /\$\s*([\d,]+)\s*k?\s*[-–—to]\s*\$?\s*([\d,]+)\s*k?/i,
      /salary[\s:]*\$?\s*([\d,]+(?:\.\d{2})?)/i
    ]
    
    salary_patterns.each do |pattern|
      match = content.match(pattern)
      return match[0] if match
    end
    
    nil
  end
  
  def extract_required_skills
    skills_section = extract_section(/(?:required|skills|qualifications)/i)
    return [] unless skills_section
    
    # Extract bullet points and common skill patterns
    skills = []
    
    # Technical skills patterns
    tech_skills = skills_section.scan(/\b(?:JavaScript|Python|Java|React|Angular|Vue|Node\.js|SQL|AWS|Docker|Kubernetes|Git|HTML|CSS|TypeScript|MongoDB|PostgreSQL|Redis|GraphQL|REST|API|Agile|Scrum|TDD|CI\/CD)\b/i)
    skills += tech_skills
    
    # General skills from bullet points
    bullet_items = skills_section.scan(/(?:^|\n)\s*[•\-\*]\s*([^\n]+)/i)
    skills += bullet_items.flatten.map(&:strip)
    
    skills.uniq.compact.reject(&:blank?)
  end
  
  def extract_preferred_qualifications
    section = extract_section(/(?:preferred|nice to have|bonus)/i)
    return [] unless section
    
    qualifications = section.scan(/(?:^|\n)\s*[•\-\*]\s*([^\n]+)/i)
    qualifications.flatten.map(&:strip)
  end
  
  def extract_benefits
    section = extract_section(/(?:benefits|perks|offer)/i)
    return [] unless section
    
    benefits = section.scan(/(?:^|\n)\s*[•\-\*]\s*([^\n]+)/i)
    benefits.flatten.map(&:strip)
  end
  
  def extract_industry
    industry_keywords = {
      'Technology' => ['software', 'tech', 'startup', 'saas', 'platform'],
      'Healthcare' => ['healthcare', 'medical', 'hospital', 'pharma'],
      'Finance' => ['finance', 'bank', 'investment', 'trading', 'fintech'],
      'Education' => ['education', 'university', 'school', 'learning'],
      'Retail' => ['retail', 'ecommerce', 'shopping', 'consumer'],
      'Manufacturing' => ['manufacturing', 'production', 'factory'],
      'Consulting' => ['consulting', 'advisory', 'professional services']
    }
    
    content_lower = content.downcase
    
    industry_keywords.each do |industry, keywords|
      return industry if keywords.any? { |keyword| content_lower.include?(keyword) }
    end
    
    nil
  end
  
  def detect_remote_work
    remote_patterns = [
      /remote/i, /work from home/i, /wfh/i, /distributed/i,
      /anywhere/i, /location independent/i
    ]
    
    remote_patterns.any? { |pattern| content.match?(pattern) }
  end
  
  def extract_deadline
    deadline_patterns = [
      /(?:deadline|apply by|applications? due)[\s:]*(\d{1,2}\/\d{1,2}\/\d{2,4})/i,
      /(?:deadline|apply by|applications? due)[\s:]*([\w\s,]+\d{1,2},?\s*\d{4})/i
    ]
    
    deadline_patterns.each do |pattern|
      match = content.match(pattern)
      return match[1].strip if match
    end
    
    nil
  end
  
  def clean_job_description
    # Remove common noise and format nicely
    cleaned = content.dup
    
    # Remove excessive whitespace
    cleaned = cleaned.gsub(/\s+/, ' ')
                    .gsub(/\n\s*\n/, "\n\n")
                    .strip
    
    # Remove common footer noise
    noise_patterns = [
      /equal opportunity employer.*/i,
      /we are an equal opportunity.*/i,
      /this job description.*/i,
      /job id:?\s*\w+/i
    ]
    
    noise_patterns.each do |pattern|
      cleaned = cleaned.gsub(pattern, '')
    end
    
    cleaned.strip
  end
  
  def extract_section(header_pattern)
    # Find content after a section header
    match = content.match(/#{header_pattern.source}[:\s]*\n?(.*?)(?=\n\n|\n[A-Z][a-z]+:|\z)/mi)
    match ? match[1] : nil
  end
  
  def extract_technical_keywords
    tech_patterns = [
      # Programming languages
      /\b(?:JavaScript|TypeScript|Python|Java|C\+\+|C#|Ruby|PHP|Go|Rust|Kotlin|Swift|Scala|R|MATLAB)\b/i,
      # Frameworks and libraries
      /\b(?:React|Angular|Vue|Node\.js|Express|Django|Flask|Rails|Spring|Laravel|\.NET)\b/i,
      # Databases
      /\b(?:MySQL|PostgreSQL|MongoDB|Redis|Elasticsearch|Oracle|SQL Server|DynamoDB)\b/i,
      # Cloud and DevOps
      /\b(?:AWS|Azure|GCP|Docker|Kubernetes|Jenkins|GitLab|CircleCI|Terraform|Ansible)\b/i,
      # Tools and technologies
      /\b(?:Git|GitHub|Jira|Confluence|Slack|Figma|Sketch|Adobe|Salesforce|HubSpot)\b/i
    ]
    
    keywords = []
    tech_patterns.each do |pattern|
      keywords += content.scan(pattern)
    end
    
    keywords.flatten.uniq
  end
  
  def extract_soft_skills
    soft_skills_patterns = [
      /\b(?:leadership|communication|teamwork|problem[_\s-]solving|analytical|creative|detail[_\s-]oriented|organized|adaptable|collaborative)\b/i
    ]
    
    keywords = []
    soft_skills_patterns.each do |pattern|
      keywords += content.scan(pattern)
    end
    
    keywords.flatten.uniq
  end
  
  def extract_industry_keywords
    # Extract domain-specific terminology
    industry_patterns = [
      # Business terms
      /\b(?:agile|scrum|kanban|waterfall|stakeholder|KPI|ROI|B2B|B2C|SaaS|API|SDK)\b/i,
      # Certifications
      /\b(?:AWS Certified|Google Cloud|Microsoft Certified|PMP|Scrum Master|Six Sigma)\b/i
    ]
    
    keywords = []
    industry_patterns.each do |pattern|
      keywords += content.scan(pattern)
    end
    
    keywords.flatten.uniq
  end
  
  def extract_certifications
    cert_patterns = [
      /\b(?:certified|certification|credential|license)\b.*?(?:\n|$)/i,
      /\b(?:CPA|MBA|PhD|MS|BS|BA|PMP|AWS|Google|Microsoft|Oracle)\b[^\n]*/i
    ]
    
    certifications = []
    cert_patterns.each do |pattern|
      certifications += content.scan(pattern)
    end
    
    certifications.flatten.map(&:strip).uniq
  end
  
  def validate!
    raise JobParsingError.new(errors.full_messages.join(", ")) unless valid?
  end
end

class JobParsingError < StandardError; end