class CoverLetter < ApplicationRecord
  belongs_to :user
  belongs_to :resume
  
  validates :company_name, presence: true, length: { minimum: 2 }
  validates :target_role, presence: true, length: { minimum: 2 }
  validates :content, presence: true, length: { minimum: 50 }, if: :content_should_be_validated?
  validates :tone, inclusion: { in: %w[professional friendly confident casual enthusiastic] }
  validates :length, inclusion: { in: %w[short medium long] }
  validates :status, inclusion: { in: %w[draft generating generated failed] }
  validates :provider, inclusion: { in: %w[openai anthropic google] }, allow_blank: true
  
  enum status: {
    draft: 'draft',
    generating: 'generating',
    generated: 'generated', 
    failed: 'failed'
  }
  
  enum :provider, {
    openai: 'openai',
    anthropic: 'anthropic',
    google: 'google'
  }, prefix: true
  
  enum :tone, {
    professional: 'professional',
    friendly: 'friendly', 
    confident: 'confident',
    casual: 'casual',
    enthusiastic: 'enthusiastic'
  }, prefix: true
  
  enum :length, {
    short: 'short',
    medium: 'medium',
    long: 'long'
  }, prefix: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_company, ->(company) { where(company_name: company) }
  scope :by_role, ->(role) { where(target_role: role) }
  scope :generated, -> { where(status: 'generated') }
  
  def generated?
    status == 'generated' && content.present?
  end
  
  def generating?
    status == 'generating'
  end
  
  def word_count
    content&.split&.size || 0
  end
  
  def estimated_read_time
    words = word_count
    return '< 1 min' if words < 200
    
    minutes = (words / 200.0).ceil
    "#{minutes} min#{minutes > 1 ? 's' : ''}"
  end
  
  def display_tone
    tone&.humanize || 'Professional'
  end
  
  def display_length
    case length
    when 'short'
      'Short (200-250 words)'
    when 'medium' 
      'Medium (300-400 words)'
    when 'long'
      'Long (450-600 words)'
    else
      'Medium'
    end
  end

  private

  def content_should_be_validated?
    status == 'generated'
  end
end
