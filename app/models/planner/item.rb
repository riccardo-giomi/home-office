class Planner::Item < ApplicationRecord
  include Core::EntityRecord

  # The states an item can be moved to, from the state it is in.
  STATE_CHANGES = {"abandoned" => %w[active], "cancelled" => %w[active], "active" => %w[abandoned cancelled]}.freeze

  belongs_to :user

  # Set only on the events a series made. `occurrence_on` is the date the rule
  # gave the event, and it stays when the event moves.
  #
  # No inverse: an unsaved occurrence must not join `series.events`,
  # or saving the series would save it.
  belongs_to :series, class_name: "Planner::Series", optional: true, inverse_of: false
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

  # Whether this is an instance of a repeating series.
  def occurrence? = series_id.present?

  # Names an occurrence by its series and the date the rule gave it. It is the
  # same before and after the occurrence is saved.
  def occurrence_key = ("series-#{series_id}-#{occurrence_on.iso8601}" if occurrence?)

  # The value of `at` in an address that asks a page to show this item: the id of
  # a saved item, or the occurrence key of an unsaved occurrence, which has no
  # id.
  def reveal_key = (new_record? && occurrence?) ? occurrence_key : id.to_s

  # Whether the item has a day and times of its own to show.
  def timed? = true

  def mark_done(done) = (self.done_at = (Time.current if done && tracks_done?))

  # What the Links pages show of an item: the state in words, or else "done",
  # and the day when the item has one of its own.
  def for_links
    status =
      if !active? then I18n.t("planner.link_status.#{state}")
      elsif done? then I18n.t("planner.link_status.done")
      end
    super.with(status:, day: (day if timed?))
  end

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
