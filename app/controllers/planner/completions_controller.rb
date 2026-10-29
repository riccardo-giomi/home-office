class Planner::CompletionsController < ApplicationController
  include Planner::ItemPages
  include Planner::ItemLookup

  def update
    item = find_item
    if item.tracks_done? && item.active?
      done = params[:done] == "1"
      item = changing(item) do |target|
        target.mark_done(done)
        target.save!
        target
      end
      flash[:notice] = item.done? ? t(".done", title: item.title) : t(".not_done", title: item.title)
    else
      flash[:alert] = t(".refused")
    end
    return redraw_dialog(item) if in_dialog?

    redirect_back_or_to default_back_path(item), status: :see_other
  end
end
