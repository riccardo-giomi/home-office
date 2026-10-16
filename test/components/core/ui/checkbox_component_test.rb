require "test_helper"

describe Core::UI::CheckboxComponent do
  include ViewComponent::TestHelpers

  it "names the checkbox by its aria-label" do
    render_inline(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Rent"))
    assert_selector "input.checkbox[type=checkbox][name=done][value='1'][aria-label='Done: Rent']"
    assert_no_selector "input[checked]"
  end

  it "shows the checked state and passes extra attributes through" do
    render_inline(Core::UI::CheckboxComponent.new(name: "done", checked: true, label: "Done: Rent", data: {action: "x#y"}))
    assert_selector "input[checked][data-action='x#y']"
  end

  it "is round, so it reads as 'done' and not as a box to select" do
    render_inline(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Rent"))
    assert_selector "input.checkbox.rounded-full"
  end
end
