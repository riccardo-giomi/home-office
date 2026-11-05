# The catch-up of the Planner.
#
# Saves as events the occurrences of series that have moved into the past.
#
# Core::CatchUpMode selects what calls `run` automatically: the requests of the
# users, a job, or nothing. The Missed events page calls `run` in every mode.
module Planner::CatchUp
  def self.run(user, today:) = Planner::Series.catch_up(user, today:)
end
