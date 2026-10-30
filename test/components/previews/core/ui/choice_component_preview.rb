class Core::UI::ChoiceComponentPreview < ViewComponent::Preview
  # A group of radio buttons: the legend names the group
  def radio_group
    form = form_for(Planner::Recurrence::Form.new(ends: "until"))
    render_group("Ends") do
      [["never", "Never"], ["until", "On a date"], ["count", "After a number of times"]].map do |value, label|
        ApplicationController.render(Core::UI::ChoiceComponent.new(form:, attribute: :ends, value:, label:, type: :radio_button), layout: false)
      end.join.html_safe
    end
  end

  # A list of check boxes, with one hint
  def check_boxes
    form = form_for(Planner::Recurrence::Form.new(weekdays: %w[MO WE]))
    render_group("Days of the week") do
      %w[MO TU WE TH FR SA SU].zip(%w[Mon Tue Wed Thu Fri Sat Sun]).map do |value, label|
        ApplicationController.render(Core::UI::ChoiceComponent.new(form:, attribute: :weekdays, value:, label:, type: :check_box, hint: ("Every Monday and Wednesday" if value == "MO")), layout: false)
      end.join.html_safe
    end
  end

  private

  def form_for(record) = ActionView::Helpers::FormBuilder.new(record.model_name.param_key, record, ActionView::Base.empty, {namespace: SecureRandom.hex(3)})

  def render_group(legend, &block) = render(Core::UI::FieldsetComponent.new(legend:), &block)
end
