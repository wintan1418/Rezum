class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  # Enums
  enum experience_level: { entry: 0, mid: 1, senior: 2, executive: 3 }
  enum subscription_status: { free: 0, trial: 1, active: 2, cancelled: 3, past_due: 4 }

  # Avatar attachment
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 64, 64 ]
    attachable.variant :medium, resize_to_limit: [ 128, 128 ]
    attachable.variant :large, resize_to_limit: [ 256, 256 ]
  end

  # Associations
  belongs_to :country, primary_key: "code", foreign_key: "country_code", optional: true
  belongs_to :referred_by, class_name: "User", optional: true
  has_many :referrals, class_name: "User", foreign_key: "referred_by_id"
  has_many :resumes, dependent: :destroy
  has_many :cover_letters, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :visits, class_name: "Ahoy::Visit"
  has_many :job_applications, dependent: :destroy
  has_many :interview_preps, dependent: :destroy
  has_many :linkedin_optimizations, dependent: :destroy
  has_many :scraped_jobs, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_one :job_scraper_setting, dependent: :destroy

  # Phone number normalization and validation
  phony_normalize :phone, default_country_code: lambda { |user| user.country_code || "US" }

  # Validations
  validates :first_name, :last_name, presence: true
  validates :referral_code, uniqueness: true, allow_nil: true
  validates :email, format: { with: /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}\z/, message: "must be a valid email address" }
  validates :country_code, inclusion: { in: ISO3166::Country.codes }, allow_nil: true
  validates :language, inclusion: { in: %w[en es fr de pt it nl sv da no] }
  validates :credits_remaining, numericality: { greater_than_or_equal_to: 0 }
  validates :phone, phony_plausible: true, allow_blank: true

  # Admin emails — these users get admin on signup
  ADMIN_EMAILS = %w[wintan1418@gmail.com].freeze

  # Callbacks
  before_create :generate_referral_code
  before_create :set_admin_if_owner
  after_create :send_welcome_email

  # Scopes
  scope :active, -> { where("last_active_at > ?", 30.days.ago) }
  scope :trial_ending_soon, -> { where(trial_ends_at: 3.days.from_now..7.days.from_now) }
  scope :by_country, ->(code) { where(country_code: code) }
  scope :inactive_for, ->(days) { where("last_active_at < ?", days.days.ago) }
  scope :low_credits, -> { where(credits_remaining: 0..1) }
  scope :admins, -> { where(admin: true) }
  scope :subscribers, -> { where(id: Subscription.where(status: :active).select(:user_id)) }
  scope :recent, -> { order(created_at: :desc) }
  scope :search, ->(query) { where("first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q", q: "%#{query}%") }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.presence || email.split("@").first.humanize
  end

  def avatar_url(variant: :medium)
    return "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(display_name)}&background=6366f1&color=fff&size=128" unless avatar.attached?

    Rails.application.routes.url_helpers.rails_representation_url(
      avatar.variant(variant),
      only_path: false
    )
  end

  def disabled?
    disabled_at.present?
  end

  def active_for_authentication?
    super && !disabled?
  end

  def inactive_message
    disabled? ? :account_disabled : super
  end

  def trial_active?
    trial? && trial_ends_at&.future?
  end

  def can_generate?
    credits_remaining > 0 || has_active_subscription? || trial_active?
  end

  # Subscription methods
  def has_active_subscription?
    subscriptions.active_subscriptions.any?(&:active?)
  end

  def current_subscription
    subscriptions.active_subscriptions.order(created_at: :desc).first
  end

  def has_premium_subscription?
    sub = current_subscription
    return false unless sub&.active?
    sub.plan_id.to_s.include?("premium")
  end

  def subscription_status
    return "free" unless current_subscription
    current_subscription.status
  end

  def preferred_currency
    currency || country&.currency || "USD"
  end

  def in_timezone(&block)
    Time.use_zone(timezone || country&.timezone || "UTC", &block)
  end

  # Phone number helpers
  def formatted_phone
    return nil if phone.blank?
    Phony.formatted(phone, format: :international, spaces: "-")
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
    parts = [ country&.name, timezone&.split("/")&.last&.humanize ].compact
    parts.join(", ")
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
    user = where(email: auth.info.email).first_or_initialize do |u|
      u.email = auth.info.email
      u.password = Devise.friendly_token[0, 20]
      u.first_name = auth.info.first_name || auth.info.name&.split&.first || "User"
      u.last_name = auth.info.last_name || auth.info.name&.split&.last || ""
      u.provider = auth.provider
      u.uid = auth.uid

      # Auto-confirm OAuth users
      u.confirmed_at = Time.current if u.respond_to?(:confirmed_at)

      # Download and attach avatar from OAuth provider
      if auth.info.image.present?
        begin
          avatar_url = auth.info.image.gsub("http://", "https://")
          u.avatar.attach(
            io: URI.open(avatar_url),
            filename: "avatar_#{u.uid}.jpg",
            content_type: "image/jpeg"
          )
        rescue => e
          Rails.logger.warn "Failed to attach avatar for user #{u.email}: #{e.message}"
        end
      end
    end

    # Auto-confirm if user already exists but isn't confirmed
    if user.persisted? && user.respond_to?(:confirmed_at) && user.confirmed_at.nil?
      user.update_column(:confirmed_at, Time.current)
    end

    user.save if user.new_record?
    user
  end

  # Payment methods
  def add_credits(amount)
    increment!(:credits_remaining, amount)
  end

  def deduct_credit!
    return false if credits_remaining <= 0 && !has_active_subscription?

    if credits_remaining > 0
      decrement!(:credits_remaining, 1)
    end
    true
  end

  def total_spent
    payments.successful.sum(:amount_cents) / 100.0
  end

  def subscription_renewal_date
    current_subscription&.current_period_end
  end

  def subscription_days_remaining
    return 0 unless current_subscription
    current_subscription.days_until_renewal
  end

  # Paystack customer methods
  def create_paystack_customer!
    return if paystack_customer_code.present?

    customer = PaystackService.create_customer(
      email: email,
      first_name: first_name,
      last_name: last_name,
      metadata: { user_id: id }
    )

    update!(paystack_customer_code: customer["customer_code"])
    customer
  end

  def paystack_customer
    return nil unless paystack_customer_code
    @paystack_customer ||= PaystackService.fetch_customer(paystack_customer_code)
  end

  private

  def generate_referral_code
    self.referral_code = SecureRandom.alphanumeric(8).upcase
  end

  def set_admin_if_owner
    self.admin = true if ADMIN_EMAILS.include?(email&.downcase)
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver_later
  end

  def subscribed_to_emails?
    marketing_consent? && unsubscribed_at.nil?
  end
end
