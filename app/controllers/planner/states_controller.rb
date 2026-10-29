# Abandon, cancel and reopen: each model define it's own rules
# (Item#change_state), this only reports what happened.
class Planner::StatesController < ApplicationController
  include Planner::ItemPages
  include Planner::ItemLookup

  # What was done, by the state the item is in afterwards
  DONE = {"abandoned" => "abandoned", "cancelled" => "cancelled", "active" => "reopened"}.freeze

  def update
    changed = false
    item = changing(find_item) do |target|
      changed = target.change_state(params[:state])
      target
    end
    if changed
      flash[:notice] = item_copy(item, DONE.fetch(item.state))
    else
      flash[:alert] = t(".refused")
    end
    return redraw_dialog(item) if in_dialog?

    redirect_to item_path(item, back: back_param), status: :see_other
  end
end
