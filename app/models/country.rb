class Country < ApplicationRecord
  self.primary_key = 'code'
  
  has_many :users, foreign_key: 'country_code'
  
  validates :code, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, presence: true
  
  scope :active, -> { where(is_active: true) }
  scope :supported, -> { where(is_active: true).order(:name) }
  
  def flag_emoji
    code.codepoints.map { |c| (c + 127397).chr(Encoding::UTF_8) }.join
  end
  
  def display_name
    "#{flag_emoji} #{name}"
  end
  
  def default_language
    supported_languages&.first || 'en'
  end
end
