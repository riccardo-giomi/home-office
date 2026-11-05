class Planner::Event < Planner::Item
  include Planner::Timed

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :calendar

  # The events that are active, not in the trash, have `tracks_done` enabled,
  # are not done and are dated before `today`, a date in the time zone of the
  # user. Use with `owned_by`.
  #
  # Unsaved occurrences are not included: Series::CatchUp saves the occurrences
  # of a series with `tracks_done` once their day has passed.
  scope :missed, ->(today) do
    kept.where(state: "active", tracks_done: 1, done_at: nil).where(day: ...today)
  end

  # The fields of an event that a person or an agent may set.
  def self.editable_attributes = super + [:tracks_done]

  # An event has the done box only when the user turns it on.
  before_validation :forget_done_without_tracking

  private

  def forget_done_without_tracking
    self.done_at = nil unless tracks_done?
  end
end
