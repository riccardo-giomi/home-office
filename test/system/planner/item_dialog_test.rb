require "application_system_test_case"

class Planner::ItemDialogSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  def make_event(title, **attrs) = Planner::Event.create!(user: admin, title:, day: Date.current, **attrs)

  def field(attribute) = Planner::Event.human_attribute_name(attribute)

  def scroll_y = evaluate_script("Math.round(window.scrollY)")

  # Where the grid sits in the window: the browser's scroll anchoring moves the
  # scroll position when a notice appears above, precisely so that this stays
  # put.
  def grid_top = evaluate_script("Math.round(document.querySelector('main table').getBoundingClientRect().top)")

  def active_inside_dialog? = evaluate_script("!!document.activeElement.closest('dialog')")

  before do
    # Fix "today" so that the grid is always consistent with what the scroll
    # assertions below expect.
    travel_to Time.utc(2026, 12, 2, 8, 10)
    use_server_time_in_browser
    admin.update!(time_zone: "UTC", time_format: "24h")
    sign_in_through_form admin
  end

  describe "a refresh of the page behind" do
    before { make_event "Standup", start_time: "09:00", end_time: "09:30" }

    # Turbo shows a cached copy of the page first when it has one, and tells the
    # page it is being cached. The dialog closes then, for the copy, but must
    # not for a refresh, which is what a change made inside it asks for.
    it "keeps the dialog open even when the page was cached before" do
      visit planner_agenda_path(view: "day")
      # leaving a page caches it: this address is left twice, so Turbo has a copy of it
      2.times do
        click_link "Next day"
        assert_no_selector "a", text: "Standup"
        click_link "Previous day"
        assert_selector "a", text: "Standup"
      end
      click_link "Standup"
      assert_selector "dialog[open] h1#dialog-title", text: "Standup"
      execute_script("Turbo.visit(location.href, {action: 'replace', shouldCacheSnapshot: false})")
      sleep 1
      assert_selector "dialog[open] h1#dialog-title", text: "Standup"
    end
  end

  describe "opening an event from the calendar or the agenda" do
    before { make_event "Standup", start_time: "09:00", end_time: "09:30", notes: "Bring the laptop" }

    it "shows it over the page, which keeps its address, its scroll and its view" do
      page.current_window.resize_to(1400, 500)
      visit planner_calendar_path(view: "month")
      execute_script("window.scrollTo(0, 180)")
      before_scroll = scroll_y
      address = current_url
      click_link "Standup"
      assert_selector "dialog[open] h1#dialog-title", text: "Standup"
      assert_text "Bring the laptop"
      assert_equal address, current_url
      assert_equal before_scroll, scroll_y
      assert_equal "dialog-title", evaluate_script("document.querySelector('dialog[open]').getAttribute('aria-labelledby')")
    end

    it "gives focus back to the link it was opened from when closed with Escape" do
      visit planner_agenda_path(view: "day")
      click_link "Standup"
      assert_selector "dialog[open]"
      find("body").send_keys(:escape)
      assert_no_selector "dialog[open]"
      assert_equal "Standup", evaluate_script("document.activeElement.textContent.trim()")
      assert_selector "#item-dialog turbo-frame:empty", visible: :all
    end

    it "closes with the close button and with a click on the backdrop" do
      visit planner_agenda_path(view: "day")
      click_link "Standup"
      find("dialog[open] button[aria-label='#{I18n.t("core.ui.modal.close")}']").click
      assert_no_selector "dialog[open]"
      click_link "Standup"
      assert_selector "dialog[open]"
      execute_script("document.querySelector('dialog[open]').dispatchEvent(new MouseEvent('click', {bubbles: true}))")
      assert_no_selector "dialog[open]"
    end

    it "keeps the keyboard inside the dialog" do
      visit planner_agenda_path(view: "day")
      click_link "Standup"
      assert_selector "dialog[open]"
      12.times do
        find("dialog[open]").send_keys(:tab)
        assert active_inside_dialog?, "focus left the dialog"
      end
    end

    it "opens a different event after another was closed, with nothing of the first left" do
      make_event "Review", start_time: "10:00", end_time: "10:30"
      visit planner_agenda_path(view: "day")
      click_link "Standup"
      assert_selector "dialog[open] h1", text: "Standup"
      find("body").send_keys(:escape)
      click_link "Review"
      assert_selector "dialog[open] h1", text: "Review"
      assert_no_text "Bring the laptop"
    end
  end

  describe "changing an event" do
    it "edits it in the same dialog; the dialog closes and the calendar behind shows the change and says so" do
      make_event "Standup", start_time: "09:00", end_time: "09:30"
      page.current_window.resize_to(1400, 500)
      visit planner_calendar_path(view: "month")
      execute_script("window.scrollTo(0, 120)")
      before_top = grid_top
      click_link "Standup"
      click_link I18n.t("planner.kinds.event.edit")
      assert_selector "dialog[open] h1", text: I18n.t("planner.kinds.event.edit_title", title: "Standup")
      fill_in field(:title), with: "Standup (moved)"
      click_button I18n.t("planner.kinds.event.submit")
      assert_no_selector "dialog[open]"
      assert_text I18n.t("planner.kinds.event.updated")
      assert_selector "td a", text: "Standup (moved)"
      # The browser's scroll anchoring moves the page in two steps (the notice appears; the page settles): measure
      # once it has settled. In Chrome the grid then sits about the height of the notice higher than before.
      sleep 0.6
      assert_in_delta before_top, grid_top, 60, "the calendar moved under the user"
      assert_includes current_url, "view=month"
    end

    it "makes a new event from New event, in the dialog" do
      visit planner_agenda_path(view: "day")
      click_link I18n.t("planner.agendas.show.new")
      assert_selector "dialog[open] h1", text: I18n.t("planner.kinds.event.new_title")
      assert_no_link I18n.t("planner.items.back.agenda")
      fill_in field(:title), with: "Made in the dialog"
      click_button I18n.t("planner.kinds.event.submit")
      assert_no_selector "dialog[open]"
      assert_text I18n.t("planner.kinds.event.created")
      assert_selector "li a", text: "Made in the dialog"
    end

    it "keeps the errors, and what was typed, in the dialog, with focus on the summary" do
      visit planner_agenda_path(view: "day")
      click_link I18n.t("planner.agendas.show.new")
      fill_in field(:title), with: "Meeting"
      fill_in field(:start_time), with: Time.utc(2000, 1, 1, 10, 0)
      fill_in field(:end_time), with: Time.utc(2000, 1, 1, 9, 0)
      click_button I18n.t("planner.kinds.event.submit")
      assert_selector "dialog[open] #error-summary"
      assert_selector "#error-summary:focus" # Turbo focuses it after two repaints
      assert_equal "Meeting", find_field(field(:title)).value
      find("#error-summary a", match: :first).click
      assert_equal "planner_event_end_time", evaluate_script("document.activeElement.id")
    end

    it "deletes an event after the confirmation, and the dialog closes" do
      make_event "Old appointment"
      visit planner_agenda_path(view: "day")
      click_link "Old appointment"
      click_link I18n.t("planner.kinds.event.edit")
      click_button I18n.t("planner.kinds.event.delete")
      within("#delete-item") { click_button I18n.t("planner.kinds.event.delete_confirm") }
      assert_no_selector "dialog[open]"
      assert_text I18n.t("planner.kinds.event.deleted")
      assert_no_selector "li a", text: "Old appointment"
    end

    it "ticks done in the dialog: it stays open, focus stays on the box, and the page behind follows" do
      make_event "Pay the rent", tracks_done: 1
      visit planner_agenda_path(view: "day")
      click_link "Pay the rent"
      id = "done_item_#{Planner::Event.find_by!(title: "Pay the rent").id}"
      find("dialog[open] ##{id}").send_keys(:space)
      assert_selector "dialog[open] input[type=checkbox][checked]"
      assert_selector "dialog[open] h1", text: "Pay the rent"
      assert_selector "dialog[open] dd", text: /Done on \d/
      assert_no_text "<time"
      assert_equal id, evaluate_script("document.activeElement.id")
      assert_selector "main s", text: "Pay the rent", visible: :all
    end
  end

  it "fills a phone and fits it" do
    make_event "Standup", start_time: "09:00", end_time: "09:30", notes: "y" * 200
    page.current_window.resize_to(320, 640)
    visit planner_agenda_path(view: "day")
    click_link "Standup"
    assert_selector "dialog[open] h1", text: "Standup"
    sleep 0.5 # the box scales in
    box = evaluate_script("(() => { const r = document.querySelector('dialog[open] .modal-box').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height), document.documentElement.clientWidth, innerHeight] })()")
    # (the test browser keeps a 15 px scrollbar gutter that a phone does not have)
    assert_operator box[0], :>=, box[2] - 20, "the dialog is narrower than the phone: #{box}"
    assert_operator box[1], :>=, box[3] - 2, "the dialog is shorter than the phone: #{box}"
    assert_no_horizontal_scroll
  end

  %w[light dark].each do |theme|
    it "has no axe violations with an event, its form and the new form open in the dialog, in the #{theme} theme" do
      admin.update!(theme:)
      make_event "Standup", start_time: "09:00", end_time: "09:30", notes: "Bring the laptop", tracks_done: 1
      visit planner_agenda_path(view: "day")
      click_link "Standup"
      assert_selector "dialog[open] h1", text: "Standup"
      sleep 0.3
      assert_accessible(within: "#item-dialog")
      click_link I18n.t("planner.kinds.event.edit")
      assert_selector "dialog[open] form#item-form"
      assert_accessible(within: "#item-dialog")
    end
  end
end
