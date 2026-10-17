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

  def with_check
    render(entry(title: "Pay the rent", starts_at: Time.utc(2026, 11, 1, 9), ends_at: Time.utc(2026, 11, 1, 9, 30), time_zone: "UTC")) do |component|
      component.with_check { checkbox }
    end
  end

  def long_title
    render(entry(title: "A" * 120, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  private

  # `render` inside a preview builds a preview request, so slot content is rendered to a string here
  def checkbox = ApplicationController.render(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Pay the rent", id: "entry-check"), layout: false).html_safe

  def entry(title: "Dentist", **attrs) = Core::UI::CalendarEntryComponent.new(title:, href: "#", **attrs)
end
