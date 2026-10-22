class Core::UI::CalendarEntryComponentPreview < ViewComponent::Preview
  def timed
    render(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 15), time_zone: "Europe/Rome"))
  end

  def all_day
    render(entry(title: "Bank holiday"))
  end

  def done
    render(entry(done: true, starts_at: Time.utc(2026, 10, 1, 9), ends_at: Time.utc(2026, 10, 1, 9, 30), time_zone: "UTC", title: "Pay the rent"))
  end

  def abandoned
    render(entry(title: "Sort the attic", state_label: "Abandoned"))
  end

  def cancelled
    render(entry(title: "Workshop", starts_at: Time.utc(2026, 10, 9, 13), ends_at: Time.utc(2026, 10, 9, 15), time_zone: "Europe/Rome", state_label: "Cancelled"))
  end

  def with_check
    render(entry(title: "Pay the rent", starts_at: Time.utc(2026, 11, 1, 9), ends_at: Time.utc(2026, 11, 1, 9, 30), time_zone: "UTC")) do |component|
      component.with_check { checkbox }
    end
  end

  def long_title
    render(entry(title: "A" * 120, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  def urgent
    render(entry(title: "Submit the tax form", priority: {level: :urgent, label: "Urgent priority"}, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  def low_priority_compact
    render(entry(title: "Tidy the desk", priority: {level: :low, label: "Low priority"}, compact: true, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  # A todo has no moment of its own: no time line at all
  def without_time
    render(entry(title: "Water the plants", show_time: false, priority: {level: :high, label: "High priority"}))
  end

  private

  # `render` inside a preview builds a preview request, so slot content is rendered to a string here
  def checkbox = ApplicationController.render(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Pay the rent", id: "entry-check"), layout: false).html_safe

  def entry(title: "Dentist", **attrs) = Core::UI::CalendarEntryComponent.new(title:, href: "#", **attrs)
end
