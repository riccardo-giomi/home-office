# Setting records aside to link them (Core::Selection).
#
# The buttons are in a record's Links section and on the rows of the lists. The
# bar that shows the selection is in the layout.
class SelectionsController < ApplicationController
  def create
    entity = Core::Entity.kept.where(user_id: Current.user.id).includes(:record).find(params[:entity_id])
    if current_selection.add(entity.id)
      answer(entity, :notice, t(".selected", title: entity.record.for_links.label))
    else
      answer(entity, :alert, t(".full"))
    end
  end

  # Unselects one record, or all of them when none is named.
  def destroy
    if params[:entity_id].present?
      current_selection.remove(params[:entity_id])
    else
      current_selection.clear
    end
    answer(Core::Entity.kept.where(user_id: Current.user.id).includes(:record).find_by(id: params[:entity_id]), :notice, t(".unselected"))
  end

  private

  # A request from a record's Links section gets the section drawn again,
  # because its buttons changed. The page behind refreshes, which draws the bar
  # and the rows again.
  def answer(entity, kind, message)
    flash[kind] = message
    respond_to do |format|
      format.turbo_stream do
        streams = []
        streams << turbo_stream.replace("links-section", helpers.links_section(entity.id)) if params[:in_section].present? && entity
        render turbo_stream: streams << turbo_stream.refresh(request_id: nil)
      end
      format.html { redirect_back_or_to root_path, status: :see_other }
    end
  end
end
