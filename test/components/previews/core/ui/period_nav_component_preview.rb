class Core::UI::PeriodNavComponentPreview < ViewComponent::Preview
  # One per page: the Theme page leaves it out
  def self.page_level? = true

  def month
    render(nav(title: "October 2026", previous_label: "Previous month", next_label: "Next month", current: 0))
  end

  def week
    render(nav(title: "Week of 10/04/2026", previous_label: "Previous week", next_label: "Next week", current: 1))
  end

  # Both themes at once, to see the resting and hover colors against each page background
  def light_and_dark
    render_with_template(template: "core/ui/period_nav_component_preview/light_and_dark", locals: {build_nav: ->(theme) { nav(title: "October 2026 (#{theme})", previous_label: "Previous month", next_label: "Next month", current: 0) }})
  end

  private

  def nav(title:, previous_label:, next_label:, current:)
    views = %w[Month Week Agenda].each_with_index.map { |name, index| [name, "#", index == current] }
    Core::UI::PeriodNavComponent.new(label: "#{title}: navigation", previous_link: [previous_label, "#"], next_link: [next_label, "#"], today_href: "#", views:)
  end
end
