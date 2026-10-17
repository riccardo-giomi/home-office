class Core::UI::MonthGridComponentPreview < ViewComponent::Preview
  # One grid per page: the Theme page leaves it out
  def self.page_level? = true

  def october
    render(grid(Date.new(2026, 10, 1), 0, october_entries))
  end

  def crowded_day_and_long_title
    day = Date.new(2026, 10, 7)
    entries = {day => [entry("A" * 90, day, 8)] + Array.new(4) { |i| entry("Meeting #{i + 1}", day, 9 + i) }}
    render(grid(Date.new(2026, 10, 1), 0, entries))
  end

  def february_in_four_rows
    render(grid(Date.new(2027, 2, 1), 1, {Date.new(2027, 2, 9) => [entry("Dentist", Date.new(2027, 2, 9), 10)]}, today: Date.new(2027, 2, 9)))
  end

  private

  def october_entries
    {
      Date.new(2026, 10, 1) => [entry("Rent October", Date.new(2026, 10, 1), 9, done: true)],
      Date.new(2026, 10, 7) => [entry("Dentist", Date.new(2026, 10, 7), 9), entry("Team lunch", Date.new(2026, 10, 7), 12)],
      Date.new(2026, 10, 8) => [{title: "Bank holiday", href: "#"}],
      Date.new(2026, 10, 20) => [entry("Review", Date.new(2026, 10, 20), 14)]
    }
  end

  def entry(title, day, hour, **attrs)
    zone = ActiveSupport::TimeZone["UTC"]
    {title:, href: "#", starts_at: zone.local(day.year, day.month, day.day, hour), ends_at: zone.local(day.year, day.month, day.day, hour + 1), time_zone: "UTC", **attrs}
  end

  def grid(month, first_weekday, entries_by_day, today: Date.new(2026, 10, 6))
    start = month.beginning_of_month.beginning_of_week(Planner::Calendar::Period::WEEKDAYS.fetch(first_weekday))
    weeks = (start..month.end_of_month.end_of_week(Planner::Calendar::Period::WEEKDAYS.fetch(first_weekday))).each_slice(7).to_a
    Core::UI::MonthGridComponent.new(weeks:, month:, today:, caption: I18n.l(month, format: "%B %Y"), day_href: ->(date) { "#day-#{date}" }, entries_by_day:)
  end
end
