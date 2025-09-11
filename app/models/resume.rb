class Resume < ApplicationRecord
  belongs_to :user
  has_many :cover_letters, dependent: :destroy
  
  # File attachments
  has_one_attached :file do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [200, 300]
  end
  
  validates :original_content, presence: true, length: { minimum: 100 }
  validates :target_role, presence: true, length: { minimum: 2 }
  validates :status, inclusion: { in: %w[draft processing optimized failed] }
  validates :provider, inclusion: { in: %w[openai anthropic google] }, allow_blank: true
  validates :ats_score, numericality: { in: 0..100 }, allow_nil: true
  
  enum status: { 
    draft: 'draft',
    processing: 'processing', 
    optimized: 'optimized',
    failed: 'failed'
  }
  
  enum provider: {
    openai: 'openai',
    anthropic: 'anthropic', 
    google: 'google'
  }, _prefix: true
  
  scope :optimized, -> { where(status: 'optimized') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_role, ->(role) { where(target_role: role) }
  
  def optimized?
    status == 'optimized' && optimized_content.present?
  end
  
  def processing?
    status == 'processing'
  end
  
  def keywords_array
    keywords&.split(',')&.map(&:strip) || []
  end
  
  def keywords_array=(array)
    self.keywords = array.join(', ') if array.present?
  end
  
  def ats_score_color
    return 'gray' if ats_score.blank?
    
    case ats_score
    when 0..40
      'red'
    when 41..70
      'yellow'
    when 71..100
      'green'
    else
      'gray'
    end
  end
end
