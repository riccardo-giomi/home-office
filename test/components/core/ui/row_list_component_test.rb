require "test_helper"

describe Core::UI::RowListComponent do
  include ViewComponent::TestHelpers

  def list(&block) = render_inline(Core::UI::RowListComponent.new(label: "Trashed items", empty_text: "Nothing here."), &block)

  it "is a labeled list with a row for each entry, the main part first and the detail on a line of its own" do
    list do |component|
      component.with_row(id: "row_1", detail: "Wed 7 · 13:00–13:30") { "Dentist" }
      component.with_row(id: "row_2") { "Rent" }
    end
    assert_selector "ol[aria-label='Trashed items'] > li", count: 2
    assert_selector "li#row_1 div", text: "Dentist"
    assert_selector "li#row_1 div + div", text: "Wed 7 · 13:00–13:30"
    assert_no_selector "li#row_2 div + div"
  end

  it "draws a row's actions after its text" do
    list { |component| component.with_row(id: "row_1", actions: "<button>Restore</button>".html_safe) { "Dentist" } }
    assert_selector "li#row_1 button", text: "Restore"
  end

  it "says what an empty list is instead of drawing one" do
    list { |_| }
    assert_text "Nothing here."
    assert_no_selector "ol"
  end
end
