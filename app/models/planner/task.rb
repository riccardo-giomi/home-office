class Planner::Task < Planner::Item
  include Planner::Timed

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :schedule

  # A task is always done or not done: the flag is not the user's to switch
  # off.
  attribute :tracks_done, default: 1
  before_validation { self.tracks_done = 1 }
end
