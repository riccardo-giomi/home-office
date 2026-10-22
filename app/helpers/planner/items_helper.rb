module Planner::ItemsHelper
  # In the dialog the page lives in the frame the dialog holds; a full page
  # needs no frame (its own forms and links must not be captured by one).
  def item_frame(&block) = in_dialog? ? turbo_frame_tag(Planner::ItemDialog::FRAME_ID, &block) : capture(&block)

  # Where "Back" goes: the page the visit began on, else the page of the item's
  # own type around its day.
  def item_back_href(item) = back_param || default_back_path(item)

  def item_back_label(item) = t("planner.items.back.#{back_location&.page || default_back_page(item)}")

  # Copy that differs by type ("Event created.", "Save event"): the shared pages
  # never name a type.
  def kind_t(item, key, **options) = t("planner.kinds.#{item.class.kind}.#{key}", **options)

  # The page's main action: opens the new-item form in the dialog over the page.
  def new_item_button(item_class, label)
    render(Core::UI::ButtonComponent.new(href: new_polymorphic_path(item_class, back: request.fullpath), data: {turbo_frame: Planner::ItemDialog::FRAME_ID})) { label }
  end

  # The dialog the item pages open in, on every page that lists items.
  def item_dialog = render(Core::UI::FrameDialogComponent.new(id: Planner::ItemDialog::ID, frame_id: Planner::ItemDialog::FRAME_ID))
end
