require "application_system_test_case"

class Planner::ScheduleSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  def make_task(title, days_ahead: 0, **attrs) = Planner::Task.create!(user: admin, title:, day: Date.current + days_ahead, **attrs)

  def field(attribute) = Planner::Task.human_attribute_name(attribute)

  def active_id = evaluate_script("document.activeElement.id")

  before do
    admin.update!(time_zone: "UTC", time_format: "24h", first_weekday: 0, locale: "en")
    Planner::Task.where(user: admin).delete_all
    sign_in_through_form admin
  end

  it "creates a task in the dialog and shows it behind, with the notice" do
    visit planner_schedule_path
    click_link I18n.t("planner.schedules.show.new")
    assert_selector "dialog[open] h1", text: I18n.t("planner.kinds.task.new_title")
    assert_no_field I18n.t("activerecord.attributes.planner/event.tracks_done")
    fill_in field(:title), with: "Write the report"
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 9, 0)
    click_button I18n.t("planner.kinds.task.submit")
    assert_no_selector "dialog[open]"
    assert_text I18n.t("planner.kinds.task.created")
    assert_selector "main li a", text: "Write the report"
  end

  it "ticks a task in place and keeps focus on its box" do
    make_task "Pay the rent", start_time: "08:00", end_time: "08:30"
    visit planner_schedule_path
    id = "done_item_#{Planner::Task.find_by!(title: "Pay the rent").id}"
    find("##{id}").send_keys(:space)
    assert_text I18n.t("planner.completions.update.done", title: "Pay the rent")
    assert_selector "main s", text: "Pay the rent", visible: :all
    assert_equal id, active_id
  end

  it "abandons a task from its dialog: the schedule says so and has no box, and a reopen brings the box back" do
    make_task "Sort the attic", start_time: "10:00", end_time: "10:30"
    visit planner_schedule_path
    click_link "Sort the attic"
    click_button I18n.t("planner.kinds.task.abandon")
    assert_selector "dialog[open] dd", text: I18n.t("planner.kinds.task.state_abandoned")
    assert_selector "main li", text: /#{I18n.t("planner.kinds.task.state_abandoned")}/, visible: :all
    assert_no_selector "main li input[type=checkbox]", visible: :all
    click_button I18n.t("planner.kinds.task.reopen")
    assert_selector "dialog[open] button", text: I18n.t("planner.kinds.task.abandon")
    assert_selector "main li input[type=checkbox]", visible: :all
  end

  it "shows an all-day task in the strip above the grid" do
    make_task "Buy stamps"
    visit planner_schedule_path
    assert_selector "main ul li", text: /#{I18n.t("core.ui.calendar_entry.all_day")}.*Buy stamps/m
  end

  it "draws the current-time line only when today is shown" do
    visit planner_schedule_path
    assert_selector "[data-controller=now-marker]", visible: :all, count: 1
    visit planner_schedule_path(date: (Date.current + 3).iso8601)
    assert_no_selector "[data-controller=now-marker]", visible: :all
  end

  it "moves a phone from the week to the day" do
    make_task "Pay the rent"
    page.current_window.resize_to(320, 800)
    visit planner_schedule_path(view: "week")
    assert_selector "h1", text: I18n.t("planner.schedules.show.title")
    assert_current_path(/view=day/)
    assert_selector "main a", text: "Pay the rent"
  end

  it "fits a 320 px screen, with a 255-character title, on the schedule and the task pages" do
    task = make_task "x" * 255
    page.current_window.resize_to(320, 800)
    [planner_schedule_path, planner_schedule_path(view: "day", date: Date.current.iso8601), planner_task_path(task), edit_planner_task_path(task), new_planner_task_path].each do |path|
      visit path
      assert_selector "h1"
      assert_fits_small_screen
    end
  end

  it "fits the week at 1280 px with tasks that overlap" do
    page.current_window.resize_to(1280, 900)
    3.times { |i| make_task "Task #{i}", start_time: "10:00", end_time: "11:00" }
    visit planner_schedule_path(view: "week")
    assert_selector "main a", text: "Task 0"
    assert_fits_small_screen
  end

  it "is operable from the keyboard: the entry opens in the dialog and Escape returns to it" do
    make_task "Pay the rent", start_time: "08:00", end_time: "08:30"
    visit planner_schedule_path
    find("main a", text: "Pay the rent").send_keys(:enter)
    assert_selector "dialog[open] h1", text: "Pay the rent"
    find("dialog[open]").send_keys(:escape)
    assert_no_selector "dialog[open]"
    assert_equal "Pay the rent", evaluate_script("document.activeElement.textContent.trim()")
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme: the schedule, a task page and the open dialog" do
      admin.update!(theme:)
      task = make_task "Pay the rent", start_time: "08:00", end_time: "08:30"
      make_task "Buy stamps"
      make_task "Sort the attic", state: "abandoned"
      [1400, 320].each do |width|
        page.current_window.resize_to(width, 900)
        [planner_schedule_path, planner_schedule_path(view: "week")].each do |path|
          visit path
          assert_selector "nav[aria-label='#{I18n.t("planner.schedules.show.nav")}']"
          assert_accessible
        end
        visit planner_task_path(task)
        assert_selector "h1", text: "Pay the rent"
        assert_accessible
        visit edit_planner_task_path(task)
        assert_selector "form#item-form"
        assert_accessible
      end
      page.current_window.resize_to(1400, 900)
      visit planner_schedule_path
      click_link "Pay the rent"
      assert_selector "dialog[open] h1"
      assert_accessible(within: "#item-dialog")
    end
  end
end
