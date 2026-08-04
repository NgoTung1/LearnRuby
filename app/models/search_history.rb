class SearchHistory < ApplicationRecord
  belongs_to :user
  validates :city_name, presence: true

  before_validation :normalize_city_name

  private 
  
  def normalize_city_name
    return if city_name.blank?
    self.city_name = city_name.to_s.squish.titleize
  end
end
