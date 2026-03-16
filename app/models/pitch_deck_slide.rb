class PitchDeckSlide < ApplicationRecord
  belongs_to :pitch_deck

  validates :slide_type, presence: true, inclusion: { in: PitchDeck::SLIDE_TYPES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(visible: true) }

  def type_label
    slide_type.titleize.gsub("_", " ")
  end

  def icon_name
    case slide_type
    when "cover" then "presentation"
    when "problem" then "exclamation-triangle"
    when "solution" then "light-bulb"
    when "why_now" then "clock"
    when "market" then "globe-alt"
    when "product" then "cube"
    when "business_model" then "currency-dollar"
    when "traction" then "trending-up"
    when "competition" then "users"
    when "team" then "user-group"
    when "financials" then "chart-bar"
    when "ask" then "hand-raised"
    else "document"
    end
  end
end
