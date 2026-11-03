require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  let(:member) { users(:member) }

  it "shows the home page without axe violations" do
    sign_in_through_form users(:admin)
    visit root_path
    assert_selector "h1", text: I18n.t("home.show.title")
    assert_accessible
  end

  def card(title) = find("main article", text: /\A#{title}/)

  def widen_to(width)
    page.driver.browser.manage.window.resize_to(width, 900)
    yield
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme, with items and with nothing" do
      member.update!(theme:, time_zone: "UTC")
      Planner::Item.delete_all
      sign_in_through_form member
      visit root_path
      assert_selector "h1", text: I18n.t("home.show.title")
      assert_selector "main article", count: 4
      assert_accessible
      Planner::Todo.create!(user: member, title: "Urgent", priority: "urgent")
      Planner::Event.create!(user: member, title: "Missed", day: Date.current - 2, tracks_done: 1)
      Planner::Event.create!(user: member, title: "Today", day: Date.current, priority: "urgent")
      Planner::Task.create!(user: member, title: "Old", day: Date.current - 3)
      visit root_path
      assert_selector "main article li a", text: "1 Urgent"
      assert_accessible
    end
  end

  it "fits 320 px in English and in Italian, with the menu panel's sub-headings readable" do
    %w[en it].each do |locale|
      member.update!(locale:)
      sign_in_through_form member
      small_screen do
        visit root_path
        assert_selector "main article", count: 4
        assert_fits_small_screen
        click_button I18n.t("core.ui.header.menu", locale:)
        assert_selector "nav#sidebar p.menu-title", text: I18n.t("planner.nav.subgroups.events", locale:)
        assert_selector "nav#sidebar p.menu-title", text: I18n.t("planner.nav.subgroups.tasks", locale:)
        assert_accessible
      end
    end
  end

  it "takes a wide screen to the calendar and the schedule, and a phone to the agenda and the day" do
    sign_in_through_form member
    visit root_path
    within(card("Events")) { click_link "This week" }
    assert_current_path(/\A#{Regexp.escape(planner_calendar_path)}\?.*view=week/)
    visit root_path
    within(card("Tasks")) { click_link "This week" }
    assert_current_path(/\A#{Regexp.escape(planner_schedule_path)}\?.*view=week/)
    widen_to(500) do
      visit root_path
      within(card("Events")) { click_link "This week" }
      assert_current_path(/\A#{Regexp.escape(planner_agenda_path)}\?.*view=week/)
      visit root_path
      within(card("Tasks")) { click_link "This week" }
      assert_current_path(/\A#{Regexp.escape(planner_schedule_path)}\?.*view=day/)
      visit root_path
      within(card("Events")) { click_link "Events" }
      assert_current_path planner_agenda_path
    end
  end

  it "can be walked with the keyboard, title then lines, card after card, with a visible focus" do
    sign_in_through_form member
    visit root_path
    find("main article h2 a", text: "Events").send_keys(:tab)
    walked = 6.times.map do
      name = evaluate_script("document.activeElement.textContent.trim()")
      style = evaluate_script("getComputedStyle(document.activeElement).outlineStyle + ' ' + getComputedStyle(document.activeElement).outlineWidth + ' ' + document.activeElement.matches(':focus-visible')")
      assert_match(/\Asolid [2-9]/, style, "no visible focus on #{name}")
      page.send_keys(:tab)
      name.sub(/\A\w+: \d+ /, "")
    end
    assert_equal ["This week", "Today", "Important", "Missed events", "Tasks", "Today"], walked
  end
end
