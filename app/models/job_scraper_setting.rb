class JobScraperSetting < ApplicationRecord
  belongs_to :user

  validates :scrape_frequency, inclusion: { in: %w[hourly twice_daily daily weekly] }
  validates :max_results_per_scrape, numericality: { in: 5..50 }

  def target_roles_list
    target_roles.is_a?(Array) ? target_roles : []
  end

  def target_locations_list
    target_locations.is_a?(Array) ? target_locations : []
  end

  def keywords_list
    keywords.is_a?(Array) ? keywords : []
  end

  def due_for_scrape?
    return true if last_scraped_at.nil?

    case scrape_frequency
    when 'hourly' then last_scraped_at < 1.hour.ago
    when 'twice_daily' then last_scraped_at < 12.hours.ago
    when 'daily' then last_scraped_at < 24.hours.ago
    when 'weekly' then last_scraped_at < 7.days.ago
    else true
    end
  end

  def frequency_label
    case scrape_frequency
    when 'hourly' then 'Every hour'
    when 'twice_daily' then 'Twice a day'
    when 'daily' then 'Once a day'
    when 'weekly' then 'Once a week'
    else scrape_frequency.humanize
    end
  end
end
