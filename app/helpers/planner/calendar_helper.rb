# Turns events into the plain hashes the Core::UI calendar components draw.
module Planner::CalendarHelper
  # Built once per request: the views ask for it in more than one place.
  # Sorted by the wall clock of each event's own zone (the query orders by
  # instant, which differs when two events were made in two zones).
  def calendar_entries_by_day(events_by_day)
    @calendar_entries_by_day ||= events_by_day.transform_values do |events|
      events.map { |event| calendar_entry(event) }.each_with_index.sort_by do |entry, index|
        [entry[:from] || -1, entry[:to] || -1, index]
      end.map(&:first)
    end
  end

  def calendar_entry(event)
    {
      title: event.title,
      href: planner_event_path(event, back: request.fullpath),
      done: event.done?,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      time_zone: event.time_zone,
      from: clock_minutes(event.start_time),
      to: clock_minutes(event.end_time),
      check: (completion_check(event) if event.tracks_done?)
    }
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
      views: Planner::Calendar::Period::VIEWS.map do |candidate|
        [t("planner.periods.views.#{candidate}"), path.call(**period.with_view(candidate).to_params), view == candidate]
      end
    )
  end

  def completion_check(event)
    form_with url: planner_event_completion_path(event), method: :patch, data: {controller: "auto-submit"} do
      render Core::UI::CheckboxComponent.new(name: "done", checked: event.done?, label: t("planner.calendars.show.done_label", title: event.title),
        id: "done_event_#{event.id}", data: {action: "auto-submit#submit"})
    end
  end

  private

  def clock_minutes(clock) = clock && (clock[0, 2].to_i * 60) + clock[3, 2].to_i
end
