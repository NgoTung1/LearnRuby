class Favorite < ApplicationRecord
  belongs_to :user

  validates :city_name, presence: true, uniqueness: { scope: :user_id, message: "đã có trong danh sách yêu thích" }

  before_validation :normalize_city_name

  private

  def normalize_city_name
    return if city_name.blank?
    self.city_name = city_name.to_s.squish.titleize
  end
end