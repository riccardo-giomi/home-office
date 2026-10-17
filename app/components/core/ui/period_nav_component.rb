# Previous / today / next and a view switch (tabs) to navigate time periods.
# It does not name the period: the sticky header's page title does.
class Core::UI::PeriodNavComponent < ApplicationComponent
  # The steps look like the tabs: separate soft buttons
  BUTTON = Core::UI::TabsComponent::BUTTON

  # previous_link and next_link are [label, href] pairs,
  # views is [[label, href, current?], ...].
  def initialize(label:, previous_link:, next_link:, today_href:, views:)
    @label = label
    @previous = previous_link
    @next = next_link
    @today_href = today_href
    @views = views
  end

  # Two lines. First the choices about what is shown: the views.
  # Then the way through time: previous, today, next.
  def call
    tag.nav(class: "mb-4 flex flex-col gap-2", "aria-label": @label) do
      safe_join([tag.div(view_switch, class: "flex flex-wrap items-center gap-2"),
        steps])
    end
  end

  private

  def steps
    tag.div(class: "flex gap-2") do
      safe_join([step(@previous, :chevron_left), link_to(t("core.ui.period_nav.today"), @today_href, class: BUTTON), step(@next, :chevron_right)])
    end
  end

  def step((text, href), icon)
    link_to(href, class: BUTTON) do
      safe_join([render(Core::UI::IconComponent.new(name: icon)), tag.span(text, class: "sr-only sm:not-sr-only")])
    end
  end

  # Hidden below sm: a phone shows the day only, so there is nothing to choose.
  def view_switch = tag.div(render(Core::UI::TabsComponent.new(items: @views)), class: "hidden sm:block")
end
