module Planner::ItemsHelper
  # The address of an item's page.
  #
  # A ghost (an occurrence nobody has touched yet) has no id: its address is its
  # series and the date the rule gave it. Anything else has its own.
  def item_path(item, **options)
    return polymorphic_path(item, **options) unless ghost?(item)

    planner_series_occurrence_path(item.series_id, item.occurrence_on.iso8601, **options)
  end

  def edit_item_path(item, **options)
    return polymorphic_path([:edit, item], **options) unless ghost?(item)

    edit_planner_series_occurrence_path(item.series_id, item.occurrence_on.iso8601, **options)
  end

  # Where ticking the box goes. A ghost is saved by the tick.
  def completion_path(item)
    return planner_item_completion_path(item) unless ghost?(item)

    planner_series_occurrence_completion_path(item.series_id, item.occurrence_on.iso8601)
  end

  # The element id of the box: the item's own, or its series and date for a
  # ghost, which has no id. Ids stay unique.
  def completion_box_id(item)
    ghost?(item) ? "done_series_#{item.series_id}_#{item.occurrence_on.iso8601}" : "done_item_#{item.id}"
  end

  def state_path(item)
    return planner_item_state_path(item) unless ghost?(item)

    planner_series_occurrence_state_path(item.series_id, item.occurrence_on.iso8601)
  end

  # The title the page was opened with, whatever has been typed since.
  #
  # The occurrence of a series has no title of its own, it uses the one from
  # its series.
  def item_title_was(item) = item.new_record? ? item.series&.title || item.title : item.title_was

  # An occurrence of a series that is not saved yet.
  def ghost?(item) = item.new_record? && item.occurrence?

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

  # The short word (the select, beside the pill on the item's page) and the full
  # name (the pill's accessible name).
  def priority_label(priority) = t("planner.items.priorities.#{priority}")

  def priority_name(priority) = t("planner.items.priority_names.#{priority}")

  def priority_choices = Planner::Item.priorities.keys.map { |priority| [priority_label(priority), priority] }

  STATE_BUTTONS = {"abandoned" => "abandon", "cancelled" => "cancel", "active" => "reopen"}.freeze

  # One small form per state the item can move to (abandon, cancel, reopen).
  def state_button(item, to)
    form_with url: state_path(item), method: :patch do
      safe_join([
        (hidden_field_tag(:back, back_param) if back_param),
        hidden_field_tag(:state, to, id: "state_#{item.id}_#{to}"),
        render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary)) { kind_t(item, STATE_BUTTONS.fetch(to)) }
      ].compact)
    end
  end

  # The page's main action: opens the new-item form in the dialog over the page.
  def new_item_button(item_class, label)
    render(Core::UI::ButtonComponent.new(href: new_polymorphic_path(item_class, back: request.fullpath), data: {turbo_frame: Planner::ItemDialog::FRAME_ID})) { label }
  end

  # The dialog the item pages open in, on every page that lists items.
  #
  # It tells the layout which frame the page has, for the selection bar.
  def item_dialog
    content_for(:dialog_frames, "#{Planner::ItemDialog::FRAME_ID} ")
    render(Core::UI::FrameDialogComponent.new(id: Planner::ItemDialog::ID, frame_id: Planner::ItemDialog::FRAME_ID))
  end
end
