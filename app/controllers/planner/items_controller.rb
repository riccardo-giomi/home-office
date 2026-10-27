# The pages every kind of item has (show, new, edit, delete), written once. A
# subclass names its model and its permitted fields; its views come from
# planner/items unless it has its own.
#
# It can be considered an "abstract controller" as no route gets to its
# actions, but its views are still available for any child inheriting from it.
class Planner::ItemsController < ApplicationController
  include Planner::ItemPages
  include Core::LinkedCreation

  before_action :set_item, only: %i[show edit update destroy]

  def show
  end

  def new
    @item = item_class.new(initial_attributes.merge(linked_attributes))
  end

  def create
    @item = item_class.new(item_params.merge(user: Current.user))
    if save_and_link(@item)
      return dialog_done(kind_t("created")) if in_dialog?

      redirect_to back_path_or_default(@item), notice: kind_t("created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      return dialog_done(kind_t("updated")) if in_dialog?

      redirect_to polymorphic_path(@item, back: back_param), notice: kind_t("updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Moves the item to the trash.
  #
  # It is not gone: the trash page restores it and the purge job removes it
  # after 30 days.
  def destroy
    @item.trash
    return dialog_done(kind_t("deleted")) if in_dialog?

    redirect_to back_path_or_default(@item), notice: kind_t("deleted"), status: :see_other
  end

  private

  def items = item_class.owned_by(Current.user).kept

  def set_item
    # The entity comes along: trashing goes through it, and strict loading
    # refuses a lazy read.
    @item = items.includes(:entity).find(params[:id])
  end

  # What a new item starts with. An item with no day of its own starts with
  # nothing.
  def initial_attributes = {day: Date.current}

  # What every kind may set; a kind adds its own.
  def permitted_attributes = %i[title notes priority]

  # Never user_id, state, time_zone or done_at: those are not for the form to
  # set.
  def item_params = params.expect(item_class.model_name.param_key => permitted_attributes)

  def back_path_or_default(item) = back_location&.path || default_back_path(item)

  def kind_t(key, **options) = t("planner.kinds.#{item_class.kind}.#{key}", **options)
end
