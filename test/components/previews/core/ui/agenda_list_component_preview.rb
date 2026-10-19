class Core::UI::AgendaListComponentPreview < ViewComponent::Preview
  # One list per page: the Theme page leaves it out
  def self.page_level? = true

  def several_days
    zone = ActiveSupport::TimeZone["UTC"]
    timed = ->(title, day, hour, **attrs) { {title:, href: "#", starts_at: zone.local(2026, 10, day, hour), ends_at: zone.local(2026, 10, day, hour + 1), time_zone: "UTC", **attrs} }
    render(Core::UI::AgendaListComponent.new(today: Date.new(2026, 10, 6), empty_text: "Nothing this month.", days: [
      {date: Date.new(2026, 10, 1), entries: [timed.call("Rent October", 1, 9, done: true)]},
      {date: Date.new(2026, 10, 6), entries: [timed.call("Standup", 6, 9), {title: "Bank holiday", href: "#"}]},
      {date: Date.new(2026, 10, 7), entries: [timed.call("A" * 100, 7, 15)]}
    ]))
  end

  # Today, with the line for the current time between what has started and what is still to come
  # (a script moves it along: it is placed by the real clock, so this example uses the real today)
  def with_current_time
    today = Date.current
    zone = Time.zone
    timed = ->(title, hour, **attrs) { {title:, href: "#", from: hour * 60, to: hour * 60 + 60, starts_at: zone.local(today.year, today.month, today.day, hour), ends_at: zone.local(today.year, today.month, today.day, hour + 1), time_zone: zone.name, **attrs} }
    render(Core::UI::AgendaListComponent.new(today:, now: Time.current, empty_text: "Nothing today.", days: [
      {date: today, entries: [{title: "Bank holiday", href: "#"}, timed.call("Early start", 0), timed.call("Midday", 12), timed.call("Evening", 22, from: 22 * 60)]}
    ]))
  end

  def empty
    render(Core::UI::AgendaListComponent.new(today: Date.new(2026, 10, 6), empty_text: "Nothing this month.", days: []))
  end
end
