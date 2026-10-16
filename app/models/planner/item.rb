class Planner::Item < ApplicationRecord
  include Core::EntityRecord

  belongs_to :user
  enum :state, {active: "active", abandoned: "abandoned", cancelled: "cancelled"}, default: :active, validate: true

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: true, length: {maximum: 255}
  validates :day, presence: true
  validates :tracks_done, inclusion: {in: [0, 1]}

  scope :owned_by, ->(user) { where(user:) }
end
