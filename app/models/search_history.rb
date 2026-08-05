class SearchHistory < ApplicationRecord
  belongs_to :user
  validates :city_name, presence: true

end
