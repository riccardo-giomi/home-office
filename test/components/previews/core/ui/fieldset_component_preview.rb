class Core::UI::FieldsetComponentPreview < ViewComponent::Preview
  # A titled set of related fields, with the hint the group shares
  def with_hint
    render(Core::UI::FieldsetComponent.new(legend: "Day hours", hint: "The grids show your day from the first hour to the end of the last one.", id: "day_hours")) do
      ApplicationController.helpers.safe_join([
        ApplicationController.helpers.select_tag(:first, ApplicationController.helpers.options_for_select(%w[06:00 07:00 08:00]), class: "select w-full mb-2", "aria-label": "First hour shown"),
        ApplicationController.helpers.select_tag(:last, ApplicationController.helpers.options_for_select(%w[20:00 21:00 22:00]), class: "select w-full", "aria-label": "Last hour shown")
      ])
    end
  end

  def without_hint
    render(Core::UI::FieldsetComponent.new(legend: "Theme")) do
      ApplicationController.helpers.select_tag(:theme, ApplicationController.helpers.options_for_select(%w[Automatic Light Dark]), class: "select w-full", "aria-label": "Theme")
    end
  end
end
