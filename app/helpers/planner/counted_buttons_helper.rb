# A button with a counter badge.
module Planner::CountedButtonsHelper
  # The link to the list of forgotten tasks, with the number of items on that
  # list.
  def forgotten_tasks_button
    counted_button(
      planner_forgotten_tasks_path, t("planner.schedules.show.forgotten"),
      Planner::Counts.for(Current.user).forgotten, "forgotten_tasks"
    )
  end

  private

  def counted_button(href, label, count, kind)
    render(Core::UI::ButtonComponent.new(variant: :secondary, href:)) do
      safe_join([
        label,
        render(Core::UI::BadgeComponent.new(count:, label: t("planner.nav.#{kind}_badge", count:)))
      ])
    end
  end
end
