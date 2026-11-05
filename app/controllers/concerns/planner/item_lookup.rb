# Finds the item.
#
# The route names it either by id, for any item, or by series and date, for an
# occurrence of a series: the row if the date has one, an unsaved occurrence
# otherwise. Only an address by series reaches the second case, whatever the
# query string says.
#
# `changing` yields the item to the block that changes it. If the item was
# unsaved and another request saved it first, it yields the row that won, so
# the block runs again on that one.
module Planner::ItemLookup
  extend ActiveSupport::Concern

  private

  def find_item
    # Only the path identifies an item, never the query string. A path with a
    # series id identifies an occurrence of that series; any other, an item.
    id_candidates = request.path_parameters
    item = if id_candidates.key?(:series_id)
      Planner::ItemRef.find(Current.user, series_id: id_candidates[:series_id], on: Date.iso8601(id_candidates[:occurrence_on].to_s))
    else
      Planner::ItemRef.find(Current.user, id: id_candidates[:item_id])
    end
    item || raise(ActiveRecord::RecordNotFound)
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end

  # Yields the item to the block that changes it (Planner::ItemRef.changing).
  def changing(item, &) = Planner::ItemRef.changing(item, &)
end
