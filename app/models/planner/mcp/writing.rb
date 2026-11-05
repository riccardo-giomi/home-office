# What the tools share.
module Planner::Mcp::Writing
  def self.not_found(ref) = "Not found: #{ref.to_s.first(40)}. #{Planner::ItemRef::HELP}"

  # Returns the series of an occurrence: the one that an unsaved occurrence
  # carries, or the one that a saved one points to (kept, and the user's).
  def self.series_of(user, item)
    item.new_record? ? item.series : Planner::Series.owned_by(user).kept.find(item.series_id)
  end
end
