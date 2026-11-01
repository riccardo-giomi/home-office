# What the calendar, the agenda and the schedule show around their entries: the
# title of the period, its navigation and, for the two pages with a time grid,
# which hours of the day the grid draws.
module Planner::CalendarHelper
  def calendar_title(period)
    case period.view
    when :week then t("planner.periods.week_of", date: format_date_text(period.range.first))
    when :day then "#{t("date.day_names")[period.date.wday]} #{format_date_text(period.date)}"
    else l(period.date, format: "%B %Y")
    end
  end

  # The navigation all pages share: path is the page's own path helper, so the
  # same period nav serves the calendar and the agenda; the labels follow the
  # view (month, week or day).
  #
  # hours: true adds the switch between the hours of the day, for the pages
  # that draw a time grid.
  #
  # extra_views: tabs added after the views of the period, each [label, href,
  # current?]. A page that is another way to read the same data, such as
  # Important, uses it to appear among the tabs.
  def period_nav(period, label:, path:, hours: false, extra_views: [])
    view = period.view
    views = period.views.map do |candidate|
      [t("planner.periods.views.#{candidate}"), path.call(**period.with_view(candidate).to_params), view == candidate]
    end
    nav = Core::UI::PeriodNavComponent.new(
      label:,
      today_href: path.call(**period.to_params.except(:date)),
      previous_link: [t("planner.periods.previous.#{view}"), path.call(**period.previous.to_params)],
      next_link: [t("planner.periods.next.#{view}"), path.call(**period.next.to_params)],
      views: views + extra_views
    )
    switch = hours_switch(period, path:) if hours
    nav.with_aside { switch } if switch
    nav
  end

  # The hours the time grids show: the user's day hours, the hours around them
  # or all of them (?hours=).
  def day_slice(period)
    Core::DaySlice.new(start_hour: Current.user.day_start_hour, end_hour: Current.user.day_end_hour, mode: period.hours)
  end

  # What the time grid is told about the slice. The notices of the entries it
  # does not draw lead to the other slice.
  def time_grid_options(period, path:)
    slice = day_slice(period)
    {
      segments: slice.segments,
      outside_href: ->(_date) { path.call(**period.with_hours(slice.other).to_params) }
    }
  end

  private

  # The switch between the slices. None where there is only one: the month, or
  # day hours that are the whole day.
  def hours_switch(period, path:)
    slice = day_slice(period)
    return if period.view == :month || slice.modes.empty?

    items = slice.modes.map do |mode|
      [t("planner.hours.#{mode}"), path.call(**period.with_hours(mode).to_params), slice.mode == mode]
    end
    render(Core::UI::TabsComponent.new(items:, label: t("planner.hours.label")))
  end
end
