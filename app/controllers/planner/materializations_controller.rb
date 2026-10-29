# Makes an unsaved occurrence a real event now, for what needs one to exist
# (links).
#
# The page then shows the event.
class Planner::MaterializationsController < ApplicationController
  include Planner::ItemPages
  include Planner::ItemLookup

  def create
    item = find_item
    item = item.series.materialize(item.occurrence_on) if item.new_record?
    return redraw_dialog(item) if in_dialog?

    redirect_to item_path(item, back: back_param), status: :see_other
  end
end
