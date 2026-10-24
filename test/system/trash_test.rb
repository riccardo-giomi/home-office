require "application_system_test_case"

class TrashSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  before do
    admin.update!(locale: "en")
    sign_in_through_form admin
  end

  it "goes from the sidebar count to the Planner's trash and back" do
    visit root_path
    assert_selector "nav#sidebar a", text: "Trash"
    assert_selector "nav#sidebar a .badge .sr-only", text: "4 items in the trash", visible: :all
    click_link "Trash", match: :first
    assert_selector "h1", text: "Trash"
    click_link "Planner"
    assert_selector "h1", text: "Trash"
    assert_current_path planner_trash_path
    click_link "Back to the trash places"
    assert_current_path trash_path
  end

  it "counts down in the sidebar after the trash is emptied" do
    visit planner_trash_path
    click_button "Empty trash"
    within("#empty-trash") { click_button "Empty trash" }
    assert_text "Trash emptied"
    assert_no_selector "nav#sidebar a[href='#{trash_path}'] .badge", visible: :all
  end

  %w[light dark].each do |theme|
    it "has no axe violations on the hub in the #{theme} theme, at desktop and phone width" do
      admin.update!(theme:)
      [1400, 320].each do |width|
        page.current_window.resize_to(width, 900)
        visit trash_path
        assert_selector "ul[aria-label='Trash by module'] a", text: "Planner"
        assert_accessible
        assert_fits_small_screen if width == 320
      end
    end
  end
end
