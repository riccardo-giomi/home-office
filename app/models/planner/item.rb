class Planner::Item < ApplicationRecord
  include Core::EntityRecord

  # The states an item can be moved to, from the state it is in.
  STATE_CHANGES = {"abandoned" => %w[active], "cancelled" => %w[active], "active" => %w[abandoned cancelled]}.freeze

  belongs_to :user
  enum :state, {active: "active", abandoned: "abandoned", cancelled: "cancelled"}, default: :active, validate: true

  # Importance of an Item, controls how it looks.
  enum :priority, {low: 0, normal: 1, high: 2, urgent: 3}, default: :normal, validate: true
  # The position of the item relative to the others of the same type.
  # Controls the order the items appear in.
  positioned on: [:user_id, :type]

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: true, length: {maximum: 255}
  validates :tracks_done, inclusion: {in: [0, 1]}

  scope :owned_by, ->(user) { where(user:) }
  # Walks index_planner_items_on_day in order (user_id, type, day, starts_at);
  # every view places an item on its own local day.
  scope :on_days, ->(days) { where(day: days).order(:day, :starts_at) }

  def self.kind = model_name.element

  def done? = done_at.present?

  def mark_done(done) = (self.done_at = (Time.current if done && tracks_done?))

  def state_changes = STATE_CHANGES.keys.select { |to| can_change_state_to?(to) }

  # Abandon (tasks, events), cancel (events), reopen.
  def change_state(to)
    to = to.to_s
    can_change_state_to?(to) && update(state: to)
  end

  private

  def can_change_state_to?(to)
    STATE_CHANGES.fetch(to, []).include?(state) && (to != "cancelled" || is_a?(Planner::Event))
  end
end
