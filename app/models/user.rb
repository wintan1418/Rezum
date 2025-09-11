class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, 
         :rememberable, :validatable, :confirmable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2, :linkedin]
  
  # Enums
  enum experience_level: { entry: 0, mid: 1, senior: 2, executive: 3 }
  enum subscription_status: { free: 0, trial: 1, active: 2, cancelled: 3, past_due: 4 }
  
  # Avatar attachment
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [64, 64]
    attachable.variant :medium, resize_to_limit: [128, 128]
    attachable.variant :large, resize_to_limit: [256, 256]
  end
  
  # Associations
  belongs_to :country, primary_key: 'code', foreign_key: 'country_code', optional: true
  belongs_to :referred_by, class_name: 'User', optional: true
  has_many :referrals, class_name: 'User', foreign_key: 'referred_by_id'
  
  # Phone number normalization and validation
  phony_normalize :phone, default_country_code: lambda { |user| user.country_code || 'US' }
  
  # Validations
  validates :first_name, :last_name, presence: true
  validates :referral_code, uniqueness: true, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country_code, inclusion: { in: ISO3166::Country.codes }, allow_nil: true
  validates :language, inclusion: { in: %w[en es fr de pt it nl sv da no] }
  validates :credits_remaining, numericality: { greater_than_or_equal_to: 0 }
  validates :phone, phony_plausible: true, allow_blank: true
  
  # Callbacks
  before_create :generate_referral_code
  after_create :send_welcome_email
  
  # Scopes
  scope :active, -> { where('last_active_at > ?', 30.days.ago) }
  scope :trial_ending_soon, -> { where(trial_ends_at: 3.days.from_now..7.days.from_now) }
  scope :by_country, ->(code) { where(country_code: code) }
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def display_name
    full_name.presence || email.split('@').first.humanize
  end
  
  def avatar_url(variant: :medium)
    return "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(display_name)}&background=6366f1&color=fff&size=128" unless avatar.attached?
    
    Rails.application.routes.url_helpers.rails_representation_url(
      avatar.variant(variant), 
      only_path: false
    )
  end
  
  def trial_active?
    trial? && trial_ends_at&.future?
  end
  
  def can_generate?
    credits_remaining > 0 || active? || trial_active?
  end
  
  def preferred_currency
    currency || country&.currency || 'USD'
  end
  
  def in_timezone(&block)
    Time.use_zone(timezone || country&.timezone || 'UTC', &block)
  end
  
  # Phone number helpers
  def formatted_phone
    return nil if phone.blank?
    Phony.formatted(phone, format: :international, spaces: '-')
  rescue
    phone
  end
  
  def phone_country_code
    return nil if phone.blank?
    Phony.country_code_from(phone)&.to_s
  rescue
    nil
  end
  
  def phone_national_number
    return nil if phone.blank?
    Phony.national(phone)
  rescue
    phone
  end
  
  # Location helpers
  def location_display
    parts = [country&.name, timezone&.split('/')&.last&.humanize].compact
    parts.join(', ')
  end
  
  def local_time
    in_timezone { Time.current }
  end
  
  def business_hours?
    hour = local_time.hour
    (9..17).include?(hour) && !local_time.weekend?
  end
  
  # OAuth methods
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name || auth.info.name&.split&.first || 'User'
      user.last_name = auth.info.last_name || auth.info.name&.split&.last || ''
      user.provider = auth.provider
      user.uid = auth.uid
      user.skip_confirmation!
      
      # Download and attach avatar from OAuth provider
      if auth.info.image.present?
        begin
          avatar_url = auth.info.image.gsub('http://', 'https://')
          user.avatar.attach(
            io: URI.open(avatar_url),
            filename: "avatar_#{user.uid}.jpg",
            content_type: 'image/jpeg'
          )
        rescue => e
          Rails.logger.warn "Failed to attach avatar for user #{user.email}: #{e.message}"
        end
      end
    end
  end
  
  private
  
  def generate_referral_code
    self.referral_code = SecureRandom.alphanumeric(8).upcase
  end
  
  def send_welcome_email
    # UserMailer.welcome_email(self).deliver_later
  end
end
