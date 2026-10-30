require "test_helper"

describe Core::UI::ChoiceComponent do
  include ViewComponent::TestHelpers

  def builder(object = Planner::Recurrence::Form.new, namespace: nil)
    ActionView::Helpers::FormBuilder.new(:repeat, object, vc_test_controller.view_context, {namespace:}.compact)
  end

  it "draws a radio button inside its own label" do
    render_inline(Core::UI::ChoiceComponent.new(form: builder, attribute: :ends, value: "until", label: "On a date", type: :radio_button))
    assert_selector "label.min-h-6", text: "On a date"
    assert_selector "label input[type=radio][name='repeat[ends]'][value=until]#repeat_ends_until"
  end

  it "checks the radio button whose value the model has" do
    render_inline(Core::UI::ChoiceComponent.new(form: builder(Planner::Recurrence::Form.new(ends: "count")), attribute: :ends, value: "count", label: "After", type: :radio_button))
    assert_selector "input[type=radio][checked]"
  end

  it "draws a check box of a list, named with brackets, checked when the model has the value" do
    form = Planner::Recurrence::Form.new(weekdays: %w[MO WE])
    render_inline(Core::UI::ChoiceComponent.new(form: builder(form), attribute: :weekdays, value: "MO", label: "Mon", type: :check_box))
    assert_selector "label input[type=checkbox][name='repeat[weekdays][]'][value=MO][checked]#repeat_weekdays_mo"
    assert_no_selector "input[type=hidden]"
    render_inline(Core::UI::ChoiceComponent.new(form: builder(form), attribute: :weekdays, value: "TU", label: "Tue", type: :check_box))
    assert_no_selector "input[checked]"
  end

  it "describes the control by its hint when it has one" do
    render_inline(Core::UI::ChoiceComponent.new(form: builder, attribute: :monthly, value: "weekday", label: "On the nth weekday", hint: "The 1st Monday", type: :radio_button))
    assert_selector "input[aria-describedby='repeat_monthly_weekday_hint']"
    assert_selector "#repeat_monthly_weekday_hint", text: "The 1st Monday"
  end

  it "passes data attributes to the input" do
    render_inline(Core::UI::ChoiceComponent.new(form: builder, attribute: :ends, value: "never", label: "Never", type: :radio_button, data: {action: "change->x#y"}))
    assert_selector "input[data-action='change->x#y']"
  end
end
