# What the calendar, the agenda and the schedule show around their entries: the
# title of the period and its navigation.
module Planner::CalendarHelper
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
end
