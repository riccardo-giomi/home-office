class Core::UI::TimeGridComponentPreview < ViewComponent::Preview
  # One grid per page: the Theme page leaves it out.
  def self.page_level? = true

  # The calendar shows the grid from 640 px up; a phone gets the day view.
  def self.wide_only? = true

  WEEK = (Date.new(2026, 10, 4)..Date.new(2026, 10, 10)).to_a.freeze

  # Seven days side by side on a time grid.
  def busy_week
    render(grid({
      WEEK[2] => [entry("Standup", 9 * 60, 9 * 60 + 15), entry("Design review", 9 * 60, 10 * 60 + 30), entry("Pairing", 9 * 60 + 30, 11 * 60), entry("Lunch", 12 * 60, 13 * 60, done: true)],
      WEEK[3] => [entry("Bank holiday"), entry("Quick call", 10 * 60, 10 * 60 + 5), entry("Dentist", 15 * 60, 16 * 60)],
      WEEK[6] => [entry("Late train", 23 * 60 + 45, 23 * 60 + 59)]
    }))
  end

  # The real current week, with the line for the current time (a script moves
  # it along the day).
  def with_current_time
    week = (Date.current.beginning_of_week..Date.current.end_of_week).to_a
    today = Date.current
    standup = entry("Standup", 9 * 60, 9 * 60 + 30)
    render(Core::UI::TimeGridComponent.new(days: week.map { |date| {date:, entries: (date == today) ? [standup] : []} }, today:, now: Time.current, agenda_href: ->(date) { "#agenda-#{date}" }))
  end

  def empty_week
    render(grid({}))
  end

  # One day, as the calendar's day view (and a phone) shows it: one wide
  # column, larger text.
  def single_day
    day = WEEK[2]
    render(grid({day => [entry("Standup", 9 * 60, 9 * 60 + 15), entry("Design review", 9 * 60, 10 * 60 + 30), entry("Pairing", 9 * 60 + 30, 11 * 60), entry("Bank holiday")]}, days: [day]))
  end

  # The worst case for the space in a card: the shortest cards (drawn 30 minutes tall) with a check, a long title and a neighbor.
  # Anything added to the card of an event is to be tried here first.
  def short_cards
    render(grid({WEEK[2] => short_entries}, days: [WEEK[2]]))
  end

  # The same in a week, where a column is narrow and the check goes above the text.
  def short_cards_in_a_week
    render(grid({WEEK[2] => short_entries, WEEK[3] => short_entries}))
  end

  def five_at_once
    render(grid({WEEK[4] => (1..5).map { |i| entry("Parallel #{i}", 9 * 60, 10 * 60) }}))
  end

  private

  def short_entries
    [entry("Quick call", 9 * 60, 9 * 60 + 15, check: check("Quick call", 1)),
      entry("A title long enough to need more than one line of the card", 9 * 60 + 30, 10 * 60, check: check("Long title", 2)),
      entry("Done and short", 9 * 60 + 30, 10 * 60, done: true, check: check("Done and short", 3)),
      entry("Short, no check", 10 * 60 + 15, 10 * 60 + 30),
      entry("Abandoned and short", 10 * 60 + 45, 11 * 60 + 15, state_label: "Abandoned")]
  end

  def check(title, id) = ApplicationController.render(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: #{title}", id: "short-check-#{id}"), layout: false).html_safe

  def entry(title, from = nil, to = nil, **attrs)
    zone = ActiveSupport::TimeZone["UTC"]
    times = from ? {starts_at: zone.local(2026, 10, 7, from / 60, from % 60), ends_at: zone.local(2026, 10, 7, to / 60, to % 60), time_zone: "UTC"} : {}
    {title:, href: "#", from:, to:, **times, **attrs}
  end

  def grid(entries, days: WEEK)
    days = days.map { |date| {date:, entries: entries.fetch(date, [])} }
    Core::UI::TimeGridComponent.new(days:, today: Date.new(2026, 10, 6), agenda_href: ->(date) { "#agenda-#{date}" })
  end
end
