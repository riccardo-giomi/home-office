class Core::UI::BadgeComponentPreview < ViewComponent::Preview
  def few
    render(Core::UI::BadgeComponent.new(count: 3, label: "3 tasks"))
  end

  def many
    render(Core::UI::BadgeComponent.new(count: 120, label: "120 tasks"))
  end

  # A badge sits beside a label inside a button or a menu link.
  def in_a_button
    render(Core::UI::ButtonComponent.new(variant: :secondary, href: "#")) { "Trash #{badge(3)}".html_safe }
  end

  private

  # `render` inside a preview builds a preview request, so slot content is
  # rendered to a string here.
  def badge(count) = ApplicationController.render(Core::UI::BadgeComponent.new(count:, label: "#{count} tasks"), layout: false)
end
