require "test_helper"

describe Core::UI::ErrorSummaryComponent do
  include ViewComponent::TestHelpers

  it "renders a focusable alert with a link to each invalid field" do
    user = ExampleUser.new(email_address: "")
    user.valid?
    render_inline(Core::UI::ErrorSummaryComponent.new(record: user))
    assert_selector "#error-summary[role=alert][tabindex='-1']"
    assert_selector "#error-summary a[href='#example_user_email_address'][data-action='focus-link#focus']"
    assert_selector "#error-summary[data-controller=focus-link]"
  end

  it "lists the errors as plain text, without bullets" do
    user = ExampleUser.new(email_address: "")
    user.valid?
    render_inline(Core::UI::ErrorSummaryComponent.new(record: user))
    assert_selector "#error-summary ul.list-none"
    assert_no_selector "#error-summary .list-disc"
  end

  it "is a soft alert whose content starts at the left edge" do
    user = ExampleUser.new(email_address: "")
    user.valid?
    render_inline(Core::UI::ErrorSummaryComponent.new(record: user))
    assert_selector "#error-summary.alert-soft.alert-error.justify-start"
  end

  it "renders nothing for a valid record" do
    render_inline(Core::UI::ErrorSummaryComponent.new(record: ExampleUser.new(email_address: "a@example.com")))
    assert_no_selector "#error-summary"
  end

  it "lists the errors of other records too, each linked to its own field" do
    user = ExampleUser.new(email_address: "")
    user.valid?
    repeat = Planner::Recurrence::Form.new(frequency: "daily", interval: 0)
    repeat.rule_for(Date.new(2026, 10, 5))
    render_inline(Core::UI::ErrorSummaryComponent.new(record: user, also: [repeat]))
    assert_selector "#error-summary a[href='#example_user_email_address']"
    assert_selector "#error-summary a[href='#repeat_interval']", text: "Interval must be a number from 1 to 99"
  end

  it "renders when only another record has errors" do
    repeat = Planner::Recurrence::Form.new(frequency: "daily", interval: 0)
    repeat.rule_for(Date.new(2026, 10, 5))
    render_inline(Core::UI::ErrorSummaryComponent.new(record: ExampleUser.new, also: [repeat]))
    assert_selector "#error-summary"
  end
end
