class Planner::Task < Planner::Item
  include Planner::Timed
  include Planner::AlwaysDone

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :schedule
end
