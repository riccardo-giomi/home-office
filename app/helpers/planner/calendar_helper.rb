# Turns events and tasks into the plain hashes the Core::UI calendar components
# draw.
module Planner::CalendarHelper
  # Built once per request: the views ask for it in more than one place.
  # Sorted by the wall clock of each item's own zone (the query orders by
  # instant, which differs when two items were made in two zones).
  def entries_by_day(items_by_day)
    @entries_by_day ||= items_by_day.transform_values do |items|
      items.map { |item| calendar_entry(item) }.each_with_index.sort_by do |entry, index|
        [entry[:from] || -1, entry[:to] || -1, index]
      end.map(&:first)
    end
  end

  # A box only for an item that can still be ticked; one that was abandoned or
  # cancelled says so instead.
  def calendar_entry(item)
    {
      title: item.title,
      href: polymorphic_path(item, back: request.fullpath),
      done: item.done?,
      link_data: {turbo_frame: Planner::ItemDialog::FRAME_ID},
      starts_at: item.starts_at,
      ends_at: item.ends_at,
      time_zone: item.time_zone,
      from: (clock_minutes(item.start_time) if item.timed?),
      to: (clock_minutes(item.end_time) if item.timed?),
      check: (completion_check(item) if item.tracks_done? && item.active?),
      muted: !item.active?,
      statuses: entry_statuses(item)
    }
  end

  STATE_ICONS = {"abandoned" => :minus_circle, "cancelled" => :x_circle}.freeze

  # What is worth knowing about an item at a glance, most important first.
  def entry_statuses(item)
    [
      (item.active? ? nil : {icon: STATE_ICONS.fetch(item.state), label: kind_t(item, "state_#{item.state}")}),
      (item.normal? ? nil : {priority: item.priority.to_sym, label: priority_name(item.priority)})
    ].compact
  end

  def calendar_title(period)
    case period.view
    when :week then t("planner.periods.week_of", date: format_date_text(period.range.first))
    when :day then "#{t("date.day_names")[period.date.wday]} #{format_date_text(period.date)}"
    else l(period.date, format: "%B %Y")
    end
  end

  # The navigation both pages share: path is the page's own path helper, so the
  # same period nav serves the calendar and the agenda; the labels follow the
  # view (month, week or day)
  def period_nav(period, label:, path:)
    view = period.view
    Core::UI::PeriodNavComponent.new(
      label:,
      today_href: path.call(view:),
      previous_link: [t("planner.periods.previous.#{view}"), path.call(**period.previous.to_params)],
      next_link: [t("planner.periods.next.#{view}"), path.call(**period.next.to_params)],
      views: period.views.map do |candidate|
        [t("planner.periods.views.#{candidate}"), path.call(**period.with_view(candidate).to_params), view == candidate]
      end
    )
  end

  def completion_check(item)
    form_with url: planner_item_completion_path(item), method: :patch, data: {controller: "auto-submit"} do
      render Core::UI::CheckboxComponent.new(name: "done", checked: item.done?, label: t("planner.calendars.show.done_label", title: item.title),
        id: "done_item_#{item.id}", data: {action: "auto-submit#submit"})
    end
  end

  private

  def clock_minutes(clock) = clock && (clock[0, 2].to_i * 60) + clock[3, 2].to_i
end
