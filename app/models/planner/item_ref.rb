# Identifies an item, including unsaved occurrences.
#
# `"123"` is the id of an item. `"s7@2026-11-03"` is the occurrence of series 7
# on the date its rule gave it: unsaved until something changes it, a row
# afterwards, and the same name for both.
#
# The controllers identify an occurrence by its address (the concern ItemLookup
# calls `find`), and the MCP tools identify it by this text. Everything is
# looked up through the user: what is not theirs, not kept or not an occurrence
# is nil.
module Planner::ItemRef
  OCCURRENCE = /\As(\d+)@(\d{4}-\d{2}-\d{2})\z/

  HELP = "A ref is an item id such as 123, or s<series id>@YYYY-MM-DD for one occurrence of a repeating event, such as s7@2026-11-03. " \
    "Things in the trash are not found by ref; list them with list_items trashed: true."

  # Returns the item the text identifies, or nil.
  def self.resolve(user, ref)
    text = ref.to_s.strip
    if (match = OCCURRENCE.match(text))
      find(user, series_id: match[1].to_i, on: Date.strptime(match[2], "%Y-%m-%d"))
    elsif /\A[1-9]\d*\z/.match?(text)
      find(user, id: text.to_i)
    end
  rescue Date::Error
    nil
  end

  # Returns an item by its id, or the occurrence of a series on a date, or nil.
  def self.find(user, id: nil, series_id: nil, on: nil)
    return Planner::Item.owned_by(user).kept.includes(:entity).find_by(id:) unless series_id

    series = Planner::Series.owned_by(user).kept.find_by(id: series_id) or return
    item = series.occurrence(on)
    item unless item&.persisted? && item.trashed?
  end

  # Yields the item to the block that changes it.
  #
  # When the item was unsaved and another request saved it first, yields the
  # row that won, and the block runs again on that one.
  def self.changing(item)
    yield item
  rescue ActiveRecord::RecordNotUnique
    raise if item.persisted?

    yield item.series.occurrence(item.occurrence_on)
  end
end
