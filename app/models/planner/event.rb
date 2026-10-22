class Planner::Event < Planner::Item
  include Planner::Timed

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :calendar

  # An event has the done box only when the user turns it on.
  before_validation :forget_done_without_tracking

  private

  def forget_done_without_tracking
    self.done_at = nil unless tracks_done?
  end
end
