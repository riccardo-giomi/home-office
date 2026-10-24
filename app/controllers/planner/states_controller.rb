# Abandon, cancel and reopen: each model define it's own rules
# (Item#change_state), this only reports what happened.
class Planner::StatesController < ApplicationController
  include Planner::ItemPages

  # What was done, by the state the item is in afterwards
  DONE = {"abandoned" => "abandoned", "cancelled" => "cancelled", "active" => "reopened"}.freeze

  def update
    item = Planner::Item.owned_by(Current.user).kept.find(params[:item_id])
    if item.change_state(params[:state])
      flash[:notice] = item_copy(item, DONE.fetch(item.state))
    else
      flash[:alert] = t(".refused")
    end
    return redraw_dialog(item) if in_dialog?

    redirect_to polymorphic_path(item, back: back_param), status: :see_other
  end
end
