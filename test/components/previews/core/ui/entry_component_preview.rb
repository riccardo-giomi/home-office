class Core::UI::EntryComponentPreview < ViewComponent::Preview
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
    render(entry(title: "Sort the attic", muted: true, statuses: [{icon: :minus_circle, label: "Abandoned"}]))
  end

  def cancelled
    render(entry(title: "Workshop", starts_at: Time.utc(2026, 10, 9, 13), ends_at: Time.utc(2026, 10, 9, 15), time_zone: "Europe/Rome", muted: true, statuses: [{icon: :x_circle, label: "Cancelled"}]))
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
    render(entry(title: "Submit the tax form", statuses: [{priority: :urgent, label: "Urgent priority"}], starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  def low_priority_compact
    render(entry(title: "Tidy the desk", statuses: [{priority: :low, label: "Low priority"}], compact: true, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC"))
  end

  # The number of links, in the line of statuses
  def with_link_count
    render(entry(title: "Dentist", starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC", statuses: [LINKS]))
  end

  def with_link_count_compact
    render(entry(title: "Dentist", compact: true, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 9, 30), time_zone: "UTC", statuses: [LINKS]))
  end

  # An occurrence of a repeating event: the chip with the repeat icon
  def repeating
    render(entry(title: "Gym", starts_at: Time.utc(2026, 10, 12, 16), ends_at: Time.utc(2026, 10, 12, 17), time_zone: "Europe/Rome", statuses: [REPEATS]))
  end

  def repeating_compact
    render(entry(title: "Gym", compact: true, starts_at: Time.utc(2026, 10, 12, 16), ends_at: Time.utc(2026, 10, 12, 16, 30), time_zone: "Europe/Rome", statuses: [REPEATS]))
  end

  # A todo has no moment of its own: no time line at all
  def without_time
    render(entry(title: "Water the plants", show_time: false, statuses: [{priority: :high, label: "High priority"}]))
  end

  # Every status at once, the worst case for a small card
  def all_statuses
    render(entry(title: "Review the plan", muted: true, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "UTC", statuses: ALL_STATUSES))
  end

  def all_statuses_compact
    render(entry(title: "Review the plan", muted: true, compact: true, starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 9, 30), time_zone: "UTC", statuses: ALL_STATUSES))
  end

  private

  LINKS = {icon: :link, label: "2 links", count: 2}.freeze
  REPEATS = {icon: :repeat, label: "Repeats"}.freeze
  ALL_STATUSES = [{icon: :minus_circle, label: "Abandoned"}, {priority: :urgent, label: "Urgent priority"}, REPEATS, LINKS].freeze

  # `render` inside a preview builds a preview request, so slot content is rendered to a string here
  def checkbox = ApplicationController.render(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Pay the rent", id: "entry-check"), layout: false).html_safe

  def entry(title: "Dentist", **attrs) = Core::UI::EntryComponent.new(title:, href: "#", **attrs)
end
