class Goal < ApplicationRecord
  has_one :current_skill

  validates :description, presence: true, length: { maximum: 500 }
end
