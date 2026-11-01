# Turns items (events, tasks and todos) into the plain hashes the Core::UI entry
# components draw, for every page that lists them.
module Planner::EntriesHelper
  # Built once per request: the views ask for it in more than one place.
  # Sorted by the wall clock of each item's own zone (the query orders by
  # instant, which differs when two items were made in two zones).
  def entries_by_day(items_by_day)
    @entries_by_day ||= items_by_day.transform_values do |items|
      items.map { |item| entry_attributes(item) }.each_with_index.sort_by do |entry, index|
        [entry[:from] || -1, entry[:to] || -1, index]
      end.map(&:first)
    end
  end

  # A box only for an item that can still be ticked; one that was abandoned or
  # cancelled says so instead.
  def entry_attributes(item)
    {
      title: item.title,
      href: item_path(item, back: request.fullpath),
      done: item.done?,
      link_data: {turbo_frame: Planner::ItemDialog::FRAME_ID},
      starts_at: item.starts_at,
      ends_at: item.ends_at,
      time_zone: item.time_zone,
      from: (clock_minutes(item.start_time) if item.timed?),
      to: (clock_minutes(item.end_time) if item.timed?),
      check: (completion_check(item) if item.tracks_done? && item.active?),
      muted: !item.active?,
      statuses: entry_statuses(item),
      commands: (select_command(item) unless unsaved_occurrence?(item)),
      reveal: reveal?(item)
    }
  end

  # True when the address asks for this item: `at` holds the id of the item to
  # show. An unsaved occurrence has no id, so no address can name it.
  def reveal?(item) = params[:at].present? && item.id.to_s == params[:at]

  STATE_ICONS = {"abandoned" => :minus_circle, "cancelled" => :x_circle}.freeze

  # What is worth knowing about an item at a glance, most important first.
  def entry_statuses(item)
    [
      (item.active? ? nil : {icon: STATE_ICONS.fetch(item.state), label: kind_t(item, "state_#{item.state}")}),
      (item.normal? ? nil : {priority: item.priority.to_sym, label: priority_name(item.priority)}),
      (item.occurrence? ? {icon: :repeat, label: t("core.ui.entry.repeats")} : nil),
      link_status(item)
    ].compact
  end

  def completion_check(item)
    form_with url: completion_path(item), method: :patch, data: {controller: "auto-submit"} do
      render Core::UI::CheckboxComponent.new(name: "done", checked: item.done?, label: t("planner.calendars.show.done_label", title: item.title),
        id: completion_box_id(item), data: {action: "auto-submit#submit"})
    end
  end

  private

  def clock_minutes(clock) = clock && (clock[0, 2].to_i * 60) + clock[3, 2].to_i
end
