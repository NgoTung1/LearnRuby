class Favorite < ApplicationRecord
  belongs_to :user

  validates :city_name, presence: true, uniqueness: { scope: :user_id, message: "Đã có trong danh sách yêu thích" }

end