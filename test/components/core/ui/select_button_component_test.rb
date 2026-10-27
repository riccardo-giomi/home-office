require "test_helper"

describe Core::UI::SelectButtonComponent do
  include ViewComponent::TestHelpers

  it "sets a record aside with a post, and says which in a name only a reader hears" do
    render_inline(Core::UI::SelectButtonComponent.new(entity_id: 7, selected: false, label: "Select", title: "Pay the rent", size: :xs))
    assert_selector "form[action='/selection'] input[name=entity_id][value='7']", visible: :all
    assert_no_selector "input[name=_method]", visible: :all
    assert_button "Select Pay the rent"
    assert_selector "button.btn-xs span.sr-only", text: "Pay the rent"
  end

  it "takes it back with a delete when it is selected" do
    render_inline(Core::UI::SelectButtonComponent.new(entity_id: 7, selected: true, label: "Unselect", title: "Pay the rent"))
    assert_selector "input[name=_method][value=delete]", visible: :all
    assert_button "Unselect Pay the rent"
  end

  it "can say it comes from a Links section, so that section is redrawn" do
    render_inline(Core::UI::SelectButtonComponent.new(entity_id: 7, selected: false, label: "Select this record", in_section: true))
    assert_selector "input[name=in_section][value='1']", visible: :all
    assert_button "Select this record"
  end
end
