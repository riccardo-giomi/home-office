# Items that are always either done or not done.
#
# Shared by tasks and todos.
module Planner::AlwaysDone
  extend ActiveSupport::Concern

  included do
    attribute :tracks_done, default: 1
    before_validation { self.tracks_done = 1 }
  end
end
