require "application_system_test_case"

class Planner::TrashSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  before do
    travel_to Time.utc(2026, 10, 7, 12)
    use_server_time_in_browser
    admin.update!(time_zone: "UTC", time_format: "24h", date_format: "dmy", locale: "en")
    sign_in_through_form admin
  end

  it "takes an event from the agenda to the trash and back" do
    visit planner_agenda_path(view: "day", date: "2026-10-07")
    click_link "Dentist"
    click_link I18n.t("planner.kinds.event.edit")
    click_button I18n.t("planner.kinds.event.delete")
    within("#delete-item") { click_button I18n.t("planner.kinds.event.delete_confirm") }
    assert_text I18n.t("planner.kinds.event.deleted")
    assert_no_selector "li a", text: "Dentist"

    visit planner_trash_path
    within("li", text: "Dentist") do
      assert_text "07/10/2026"
      assert_text "09:30–10:00" # the event keeps the zone it was made in (Rome)
      click_button "Restore"
    end
    assert_text "“Dentist” restored."
    assert_selector "main h1:focus"
    assert_no_selector "main ol li", text: "Dentist"

    visit planner_agenda_path(view: "day", date: "2026-10-07")
    assert_selector "li a", text: "Dentist"
  end

  it "filters by kind with the tabs and empties the trash after a confirmation" do
    visit planner_trash_path
    click_link "Tasks (1)"
    assert_selector "main ol > li", count: 1
    assert_selector "a[aria-current=true]", text: "Tasks (1)"
    click_button "Empty trash"
    within("#empty-trash") do
      assert_text "All 4 items in the trash will be deleted for good"
      click_button "Empty trash"
    end
    assert_text "Trash emptied: 4 items deleted for good."
    assert_text "The trash is empty."
    assert_no_button "Empty trash"
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme, at desktop and phone width, with the confirmation open and with an empty trash" do
      admin.update!(theme:)
      [1400, 320].each do |width|
        page.current_window.resize_to(width, 900)
        visit planner_trash_path
        assert_selector "main ol > li", count: 4
        assert_accessible
        assert_fits_small_screen if width == 320
      end
      click_button "Empty trash"
      sleep 0.4 # The dialog fades in; axe must not read mid-transition colors.
      assert_selector "dialog[open] h2", text: "Empty the trash?"
      assert_accessible
      find("dialog[open] form[method=dialog] button").click
      Planner::Item.owned_by(admin).trashed.delete_all
      visit planner_trash_path
      assert_text "The trash is empty."
      assert_accessible
    end
  end

  it "keeps a long title and the second line inside a 320 px screen" do
    Planner::Event.create!(user: admin, title: "x" * 200, day: Date.current, start_time: "09:00", end_time: "10:00").trash
    page.current_window.resize_to(320, 800)
    visit planner_trash_path
    assert_selector "main ol > li", count: 5
    assert_fits_small_screen
  end
end
