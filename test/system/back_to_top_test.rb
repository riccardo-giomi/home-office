require "application_system_test_case"

class BackToTopTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "UTC", locale: "en")
    Planner::Event.where(user: admin).delete_all
    40.times { |number| Planner::Event.create!(user: admin, title: "Event #{number}", day: Date.current, start_time: format("%02d:00", number % 24), end_time: format("%02d:30", number % 24)) }
    sign_in_through_form admin
    visit_agenda
    assert_selector "h1"
    assert_operator evaluate_script("document.documentElement.scrollHeight"), :>, 2 * evaluate_script("innerHeight")
  end

  def label = I18n.t("core.ui.back_to_top.label")

  # Asked for by date, the agenda opens at the top; without a date it opens on today
  def visit_agenda = visit planner_agenda_path(view: "day", date: Date.current.iso8601)

  def scroll_down = execute_script("window.scrollTo(0, 3 * innerHeight)")

  def scroll_y = evaluate_script("Math.round(window.scrollY)")

  def active = evaluate_script("document.activeElement.tagName + ':' + (document.activeElement.dataset.controller || '')")

  it "is neither seen nor reachable with the keyboard at the top of the page" do
    assert_no_button label
    assert_selector "button[data-controller=back-to-top].invisible", visible: :all
    10.times do
      send_keys(:tab)
      refute_match(/back-to-top/, active)
    end
  end

  def scroll_past_heading = execute_script("const h = document.querySelector('main h1').getBoundingClientRect(); window.scrollTo(0, window.scrollY + h.bottom)")

  it "waits for the page heading to leave: a little scrolling is not enough, the heading out of sight is" do
    execute_script("window.scrollTo(0, 20)")
    assert_selector "button[data-controller=back-to-top].invisible", visible: :all
    scroll_past_heading
    assert_button label
  end

  it "appears once the page has been scrolled past its heading and goes again at the top" do
    scroll_down
    assert_button label
    execute_script("window.scrollTo(0, 0)")
    assert_no_button label
  end

  it "stays when the page refreshes in place while it is scrolled down (a tick, a restore)" do
    scroll_down
    assert_button label
    execute_script("Turbo.session.refresh(location.href)")
    sleep 0.8
    assert_button label
  end

  it "takes the visitor to the top and puts focus on the page heading" do
    scroll_down
    click_button label
    assert_equal 0, scroll_y
    assert_equal "H1:", active
    assert_no_button label
  end

  it "does the same from the keyboard" do
    scroll_down
    assert_button label
    find_button(label).send_keys(:enter)
    assert_equal 0, scroll_y
    assert_equal "H1:", active
  end

  it "does not move the rest of the header when it appears" do
    switch_x = -> { evaluate_script("document.querySelector('[data-controller=theme-switch]').getBoundingClientRect().left") }
    before = switch_x.call
    scroll_down
    assert_button label
    assert_in_delta before, switch_x.call, 0.5
  end

  it "is at least 24 px wide and high, and has a visible focus ring" do
    scroll_down
    size = evaluate_script("(() => { const r = document.querySelector('[data-controller=back-to-top]').getBoundingClientRect(); return [r.width, r.height] })()")
    assert size.all? { |side| side >= 24 }, size.inspect
    # The ring shows for keyboard focus only: arrive with the Shift+Tab key, from the theme switch beside it
    execute_script("document.querySelector('[data-controller=theme-switch]').focus()")
    send_keys([:shift, :tab])
    assert_includes active, "back-to-top"
    outline = evaluate_script("getComputedStyle(document.querySelector('[data-controller=back-to-top]')).outlineStyle")
    refute_equal "none", outline
  end

  %w[light dark].each do |theme|
    it "has no axe violations when shown, in the #{theme} theme" do
      admin.update!(theme:)
      visit_agenda
      scroll_down
      assert_button label
      assert_accessible
    end
  end

  it "fits 320 px, and the header still names the app" do
    page.current_window.resize_to(320, 700)
    visit_agenda
    scroll_down
    assert_button label
    assert_fits_small_screen
    assert_selector "header", text: I18n.t("core.app_name")
  end
end
