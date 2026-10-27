require "application_system_test_case"

# The Links section of a record, on its page and in the dialog; the three kinds behave alike
class LinksSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }
  let(:kinds) { {"event" => :holiday, "task" => :buy_stamps_task, "todo" => :water_plants_todo} }

  before do
    travel_to Time.utc(2026, 10, 7, 12)
    admin.update!(time_zone: "UTC", time_format: "24h", date_format: "dmy", locale: "en")
    sign_in_through_form admin
  end

  def heading_count = find("h2#links-section-heading").text[/\((\d+)\)/, 1].to_i

  def pick(title, tab: "Tasks")
    click_link "Add link"
    assert_selector "#link-picker-panel"
    within("#links-section-picker") do
      click_link tab
      assert_selector "a[aria-current=true]", text: tab
      fill_in "Search by title", with: title
      click_button "Search"
      assert_selector "#link-picker-panel li" # the results are in, so what follows does not meet the old frame
    end
  end

  def focused_id = evaluate_script("document.activeElement.id")

  %w[event task todo].each do |kind|
    describe "on a #{kind}'s page" do
      let(:record) { planner_items(kinds.fetch(kind)) }

      it "adds a link by searching, says so, and hands focus to the section heading" do
        visit polymorphic_path(record)
        before = heading_count
        pick("passport")
        within("#links-section-picker") { click_button "Link Renew the passport" }
        assert_selector "h2#links-section-heading", text: "Links (#{before + 1})"
        assert_selector "#links-section a", text: "Renew the passport"
        assert_text "Linked to Renew the passport."
        assert_selector "#links-section-heading:focus"
        assert_no_selector "#link-picker-panel"
      end

      it "marks what is linked already, and links nothing twice" do
        visit polymorphic_path(record)
        pick("passport")
        within("#links-section-picker") { click_button "Link Renew the passport" }
        assert_selector "#links-section p[role=status]"
        assert_no_selector "#links-section p[role=status]" # the page behind has refreshed
        pick("passport")
        within("#links-section-picker") do
          assert_text "Already linked"
          assert_no_button "Link Renew the passport"
        end
      end

      it "removes a link at once, without a question" do
        Core::Link.connect(admin, record.id, planner_items(:passport_task).id)
        visit polymorphic_path(record)
        before = heading_count
        click_button "Remove link to Renew the passport"
        assert_selector "h2#links-section-heading", text: "Links (#{before - 1})"
        assert_no_selector "#links-section a", text: "Renew the passport"
        assert_selector "#links-section-heading:focus"
      end

      it "changes the other end" do
        Core::Link.connect(admin, record.id, planner_items(:passport_task).id)
        visit polymorphic_path(record)
        before = heading_count
        click_link "Change Renew the passport"
        within("#links-section-picker") do
          fill_in "Search by title", with: "Call the bank"
          click_button "Search"
          click_button "Link Call the bank"
        end
        assert_selector "#links-section a", text: "Call the bank"
        assert_no_selector "#links-section a", text: "Renew the passport"
        assert_equal before, heading_count
      end
    end
  end

  it "shows an end in the trash in words, and keeps the link when it is restored" do
    link = core_links(:dentist_and_trashed_task)
    visit planner_event_path(planner_items(:dentist))
    within("#link_#{link.id}") do
      assert_selector "s", text: planner_items(:trashed_task).title
      assert_text "in the trash"
      assert_link "See the trash"
    end
    planner_items(:trashed_task).restore
    visit planner_event_path(planner_items(:dentist))
    assert_selector "#link_#{link.id} a", text: planner_items(:trashed_task).title
    assert_no_selector "#links-section", text: "in the trash"
  end

  describe "in the dialog of the agenda" do
    it "adds and removes a link inside the dialog, which stays open, while the page behind keeps its place" do
      visit planner_agenda_path(view: "day", date: "2026-10-07")
      click_link "Dentist"
      within("dialog[open]") do
        before = heading_count
        pick("passport")
        click_button "Link Renew the passport"
        assert_selector "h2#links-section-heading", text: "Links (#{before + 1})"
        assert_text "Linked to Renew the passport."
        assert_selector "#links-section-heading:focus"
        click_button "Remove link to Renew the passport"
        assert_selector "h2#links-section-heading", text: "Links (#{before})"
      end
      assert_selector "dialog[open]"
      assert_equal "/planner/agenda?date=2026-10-07&view=day", URI(current_url).request_uri.then { |uri| URI(uri).path + "?" + URI(uri).query.split("&").sort.join("&") }
    end
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme, at desktop and phone width, with the picker open and a long title" do
      admin.update!(theme:)
      planner_items(:pay_rent_task).update_columns(title: "W" * 255)
      [1400, 320].each do |width|
        page.current_window.resize_to(width, 900)
        visit planner_event_path(planner_items(:dentist))
        assert_accessible
        assert_fits_small_screen if width == 320
        pick("passport", tab: "Tasks")
        assert_selector "#links-section-picker li", text: "Renew the passport"
        assert_accessible
        assert_fits_small_screen if width == 320
      end
    end
  end

  it "can be used with the keyboard alone" do
    visit planner_todo_path(planner_items(:water_plants_todo))
    find("a", text: "Add link").send_keys(:enter)
    assert_selector "#link-picker-panel"
    find("#links-section-picker a", text: "Tasks").send_keys(:enter)
    assert_selector "#links-section-picker a[aria-current=true]", text: "Tasks"
    find("#q").send_keys("passport", :enter)
    find_button("Link Renew the passport").send_keys(:enter)
    assert_selector "#links-section a", text: "Renew the passport"
    assert_selector "#links-section-heading:focus"
  end

  describe "the selection" do
    def select_here = click_button("Select this record").then { assert_selector "[aria-label='Selected records']" }

    it "sets a record aside, follows to other pages, and links another record to it" do
      visit planner_event_path(planner_items(:holiday))
      select_here
      assert_selector "[aria-label='Selected records'] a", text: "Bank holiday"
      assert_button "Unselect this record"
      visit planner_todo_path(planner_items(:water_plants_todo))
      assert_selector "[aria-label='Selected records'] a", text: "Bank holiday"
      before = heading_count
      click_button "Link to selected: Bank holiday"
      assert_selector "h2#links-section-heading", text: "Links (#{before + 1})"
      assert_text "Linked to Bank holiday."
      assert_selector "#links-section-heading:focus"
      assert_selector "[aria-label='Selected records'] a", text: "Bank holiday" # the selection stays
      assert_no_selector "button", text: /Link to selected/ # it is linked now
    end

    it "links the two selected records from the bar, and empties it" do
      visit planner_event_path(planner_items(:holiday))
      select_here
      visit planner_todo_path(planner_items(:water_plants_todo))
      select_here
      assert_selector "[aria-label='Selected records'] a", count: 2
      click_button "Link these two"
      assert_text "Linked to"
      assert_no_selector "[aria-label='Selected records']"
      assert Core::Link.existing(admin.id, planner_items(:holiday).id, planner_items(:water_plants_todo).id)
    end

    it "unselects one from the bar, and clears" do
      visit planner_event_path(planner_items(:holiday))
      select_here
      click_button "Unselect Bank holiday"
      assert_no_selector "[aria-label='Selected records']"
      select_here
      click_button "Clear selection"
      assert_no_selector "[aria-label='Selected records']"
      assert_button "Select this record"
    end

    it "refuses a third, and says so" do
      visit planner_event_path(planner_items(:holiday))
      select_here
      visit planner_todo_path(planner_items(:water_plants_todo))
      select_here
      visit planner_task_path(planner_items(:buy_stamps_task))
      click_button "Select this record"
      assert_text "Two records are already selected. Unselect one first."
      assert_selector "[aria-label='Selected records'] a", count: 2
    end

    it "forgets a selected record that goes to the trash" do
      visit planner_event_path(planner_items(:holiday))
      select_here
      planner_items(:holiday).trash
      visit planner_calendar_path
      assert_no_selector "[aria-label='Selected records']"
    end

    it "works in the dialog: selecting redraws the section there and the bar appears behind" do
      visit planner_agenda_path(view: "day", date: "2026-10-07")
      click_link "Dentist"
      within("dialog[open]") do
        click_button "Select this record"
        assert_button "Unselect this record"
      end
      assert_selector "dialog[open]"
      assert_selector "[aria-label='Selected records'] a", text: "Dentist", visible: :all
    end

    %w[light dark].each do |theme|
      it "has no axe violations in the #{theme} theme with two selected, at desktop and phone width" do
        admin.update!(theme:)
        [1400, 320].each do |width|
          page.current_window.resize_to(width, 900)
          visit planner_event_path(planner_items(:holiday))
          select_here if has_button?("Select this record")
          visit planner_todo_path(planner_items(:water_plants_todo))
          select_here if has_button?("Select this record")
          assert_selector "[aria-label='Selected records'] a", count: 2
          planner_items(:holiday).update_columns(title: "W" * 255) if width == 320
          visit planner_todo_path(planner_items(:water_plants_todo))
          assert_accessible
          assert_fits_small_screen if width == 320
        end
      end
    end
  end
end
