# Finds the item a change is about.
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
    # What the address says, not what the query string adds: only an address by
    # series names a series.
    named = request.path_parameters
    return Planner::Item.owned_by(Current.user).kept.find(named[:item_id]) unless named.key?(:series_id)

    series = Planner::Series.owned_by(Current.user).kept.find(named[:series_id])
    item = series.occurrence(Date.iso8601(named[:occurrence_on].to_s)) || raise(ActiveRecord::RecordNotFound)
    raise ActiveRecord::RecordNotFound if item.persisted? && item.trashed?

    item
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end

  # Yields the item to the block that changes it.
  #
  # When the item was unsaved and another request saved it first, yields the
  # row that won, and the block runs again on that one.
  def changing(item)
    yield item
  rescue ActiveRecord::RecordNotUnique
    raise if item.persisted?

    yield item.series.occurrence(item.occurrence_on)
  end
end
