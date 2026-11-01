require "test_helper"

describe Core::UI::DateFieldComponent do
  include ViewComponent::TestHelpers

  def builder(user, namespace: nil)
    ActionView::Helpers::FormBuilder.new(:example_user, user, vc_test_controller.view_context, {namespace:})
  end

  def render_field(day, **options)
    render_inline(Core::UI::DateFieldComponent.new(form: builder(ExampleUser.new(day:)), attribute: :day, label: "Day", **options))
  end

  # The English default is month/day/year: the same digits mean another day for
  # a user who chose day/month/year.
  it "says the weekday and the date in the user's format, between the label and the input" do
    render_field(Date.new(2026, 12, 1))
    assert_selector "label[for=example_user_day] + p#example_user_day_readout + input#example_user_day[type=date]"
    assert_selector "p#example_user_day_readout", text: "Tuesday 12/01/2026"
  end

  it "reads a date given as the text of the input" do
    render_field("2026-12-01")
    assert_selector "p#example_user_day_readout", text: "Tuesday 12/01/2026"
  end

  it "says nothing for an empty or unreadable value" do
    render_field(nil)
    assert_selector "p#example_user_day_readout", text: ""
    render_field("not a date")
    assert_selector "p#example_user_day_readout", text: ""
  end

  it "describes the input by the line first, then the hint" do
    render_field(Date.new(2026, 12, 1), hint: "Any day")
    assert_selector "input#example_user_day[aria-describedby='example_user_day_readout example_user_day_hint']"
  end

  it "gives the controller the pattern, the names of the days and the input to watch" do
    render_field(Date.new(2026, 12, 1))
    assert_selector "div[data-controller=date-readout][data-date-readout-pattern-value='%m/%d/%Y']"
    assert_selector "div[data-date-readout-day-names-value*='Tuesday']"
    assert_selector "input[data-date-readout-target=input][data-action='input->date-readout#update change->date-readout#update']"
    assert_selector "p[data-date-readout-target=text]"
  end

  it "keeps the data and the options the caller gave the input" do
    render_field(Date.new(2026, 12, 1), required: true, data: {extra: "yes"})
    assert_selector "input[required][data-extra=yes][data-date-readout-target=input]"
  end
end
