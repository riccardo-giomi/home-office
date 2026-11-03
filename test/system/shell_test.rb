require "application_system_test_case"

class ShellTest < ApplicationSystemTestCase
  it "starts with the skip link, which moves focus into the page" do
    sign_in_through_form users(:member)
    # Chrome starts Tab from the position of the last click, even on the next
    # page, and the home page has links at that position now.
    visit root_path
    find("body").send_keys(:tab)
    assert_equal I18n.t("core.ui.skip_link"), evaluate_script("document.activeElement.textContent.trim()")
    send_keys(:enter)
    assert_equal "main-content", evaluate_script("document.activeElement.id")
  end

  it "has the landmarks once each and a live region" do
    sign_in_through_form users(:admin)
    assert_selector "header", count: 1
    assert_selector "main", count: 1
    assert_selector "nav[aria-label]", count: 1
    assert_selector "#announcements[aria-live=polite]", count: 1, visible: :all
  end

  it "shows the sidebar on a wide screen with the current page marked, and hides admin entries from members" do
    sign_in_through_form users(:member)
    assert_selector "nav a[aria-current=page]", text: I18n.t("core.nav.home")
    assert_no_selector "nav a", text: I18n.t("core.nav.users")
    assert_no_button I18n.t("core.ui.header.menu")
  end

  it "keeps the sidebar a panel below 1280 px, so a 1072 px page body has the whole width" do
    sign_in_through_form users(:member)
    page.current_window.resize_to(1100, 900)
    visit root_path
    assert_no_selector "nav#sidebar", visible: :visible
    assert_button I18n.t("core.ui.header.menu")
    page.current_window.resize_to(1280, 900)
    visit root_path
    assert_selector "nav#sidebar", visible: :visible
    assert_no_button I18n.t("core.ui.header.menu")
  end

  it "opens the sidebar as a panel on a small screen and puts focus back on the menu button" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:admin)
    assert_no_selector "nav#sidebar", visible: :visible
    click_button I18n.t("core.ui.header.menu")
    assert_selector "nav#sidebar", visible: :visible
    assert_equal "true", find_button(I18n.t("core.ui.header.menu"))["aria-expanded"]
    assert_equal true, evaluate_script("document.querySelector('main').inert")
    assert evaluate_script("document.querySelector('#sidebar').contains(document.activeElement)")
    send_keys(:escape)
    assert_no_selector "nav#sidebar", visible: :visible
    assert_equal I18n.t("core.ui.header.menu"), evaluate_script("document.activeElement.textContent.trim()")
    assert_equal false, evaluate_script("document.querySelector('main').inert")
  end

  it "closes the panel when a link is followed" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:member)
    click_button I18n.t("core.ui.header.menu")
    click_link I18n.t("core.nav.preferences")
    assert_selector "h1", text: I18n.t("preferences.edit.title")
    assert_no_selector "nav#sidebar", visible: :visible
  end

  it "moves focus to the page heading after a Turbo visit" do
    sign_in_through_form users(:member)
    click_link I18n.t("core.nav.preferences")
    assert_selector "h1", text: I18n.t("preferences.edit.title")
    assert_equal "H1", evaluate_script("document.activeElement.tagName")
  end

  it "applies the stored theme at once and Automatic removes it after a Turbo form" do
    users(:member).update!(theme: "dark")
    sign_in_through_form users(:member)
    assert_selector "html[data-theme=dark]"
    visit edit_preferences_path
    select I18n.t("preferences.automatic"), from: User.human_attribute_name(:theme)
    click_button I18n.t("preferences.edit.submit")
    assert_selector "[role=status]", text: I18n.t("preferences.update.updated")
    assert_no_selector "html[data-theme]"
  end

  it "switches theme from the keyboard and keeps it after a reload" do
    sign_in_through_form users(:member)
    switch = find("[role=switch]")
    assert_equal "false", switch["aria-checked"]
    switch.send_keys(:space)
    assert_selector "html[data-theme=dark]"
    assert_equal "true", find("[role=switch]")["aria-checked"]
    # The save is a background request
    50.times do
      break if users(:member).reload.theme
      sleep 0.1
    end
    assert_equal "dark", users(:member).theme
    visit root_path
    assert_selector "html[data-theme=dark]"
    assert_equal "true", find("[role=switch]")["aria-checked"]
  end

  %w[light dark].each do |theme|
    it "has no axe violations on every page in the #{theme} theme" do
      users(:admin).update!(theme:)
      sign_in_through_form users(:admin)
      [root_path, edit_preferences_path, admin_users_path, new_admin_user_path, admin_theme_path].each do |path|
        visit path
        assert_selector "html[data-theme=#{theme}]"
        assert_accessible
      end
    end

    it "has no axe violations with the small-screen menu open in the #{theme} theme" do
      page.current_window.resize_to(320, 640)
      users(:admin).update!(theme:)
      sign_in_through_form users(:admin)
      click_button I18n.t("core.ui.header.menu")
      assert_selector "nav#sidebar", visible: :visible
      assert_accessible(within: "nav#sidebar")
    end

    it "shows the error states without axe violations in the #{theme} theme" do
      users(:member).update!(theme:)
      sign_in_through_form users(:member)
      visit edit_preferences_path
      page.execute_script("const s = document.querySelector('#user_time_zone'); s.insertAdjacentHTML('beforeend', '<option value=\"Mars/Base\">Mars</option>'); s.value = 'Mars/Base'")
      click_button I18n.t("preferences.edit.submit")
      assert_selector "#error-summary"
      assert_accessible
    end

    it "has no axe violations on the sign-in page in the #{theme} theme" do
      visit new_session_path
      page.driver.browser.manage.add_cookie(name: "theme", value: theme)
      visit new_session_path
      assert_selector "html[data-theme=#{theme}]"
      assert_accessible
    end
  end

  it "fits a 320 px screen on every page, signed in and out" do
    page.current_window.resize_to(320, 640)
    visit new_session_path
    assert_fits_small_screen
    sign_in_through_form users(:admin)
    [root_path, edit_preferences_path, admin_users_path, admin_theme_path].each do |path|
      visit path
      assert_fits_small_screen
    end
  end

  it "styles the sign-in page from the theme cookie before sign-in" do
    visit new_session_path
    find("[role=switch]").click
    assert_selector "html[data-theme=dark]"
    visit new_session_path
    assert_selector "html[data-theme=dark]"
    assert_accessible
  end

  def wait_for_saved_theme(user)
    50.times do
      break if user.reload.theme
      sleep 0.1
    end
  end

  it "keeps the theme when going back to a page Turbo cached before the switch" do
    sign_in_through_form users(:member)
    find("[role=switch]").click
    assert_selector "html[data-theme=dark]"
    wait_for_saved_theme(users(:member))
    click_link I18n.t("core.nav.preferences")
    assert_selector "h1", text: I18n.t("preferences.edit.title")
    go_back
    assert_selector "h1", text: I18n.t("home.show.title")
    assert_selector "html[data-theme=dark]"
  end

  it "keeps a theme chosen on the preferences page when going back to a cached page" do
    sign_in_through_form users(:member)
    click_link I18n.t("core.nav.preferences")
    assert_selector "h1", text: I18n.t("preferences.edit.title")
    select I18n.t("preferences.themes.dark"), from: User.human_attribute_name(:theme)
    click_button I18n.t("preferences.edit.submit")
    assert_selector "[role=status]", text: I18n.t("preferences.update.updated")
    assert_selector "html[data-theme=dark]"
    go_back
    assert_selector "h1", text: I18n.t("home.show.title")
    assert_selector "html[data-theme=dark]"
  end

  it "keeps the header in view while a long page scrolls" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:admin)
    visit admin_theme_path
    execute_script("window.scrollTo(0, 600)")
    assert_operator evaluate_script("window.scrollY"), :>, 100
    assert_equal 0, evaluate_script("Math.round(document.querySelector('header').getBoundingClientRect().top)")
  end

  it "makes the header and the page inert while the small-screen menu is open" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:admin)
    click_button I18n.t("core.ui.header.menu")
    assert_equal true, evaluate_script("document.querySelector('header').inert")
    assert_equal true, evaluate_script("document.querySelector('main').inert")
    send_keys(:escape)
    assert_equal false, evaluate_script("document.querySelector('header').inert")
    assert_equal I18n.t("core.ui.header.menu"), evaluate_script("document.activeElement.textContent.trim()")
  end

  describe "the clock in the header" do
    before do
      users(:member).update!(time_zone: "Europe/Rome", time_format: "24h", date_format: "dmy", locale: "en")
      sign_in_through_form users(:member)
    end

    def clock_text = evaluate_script("document.querySelector('header time').textContent.replace(/\\s+/g, ' ').trim()")

    it "shows the weekday, the date and the time in the user's zone and formats" do
      now = Time.current.in_time_zone("Europe/Rome")
      assert_match(/\A#{now.strftime("%a %d/%m/%Y")} \d\d:\d\d\z/, clock_text)
      assert_selector "header time[datetime]", visible: :all
    end

    it "follows the clock when the minute changes, without a reload" do
      execute_script("const real = Date.now; Date.now = () => real.call(Date) + 3 * 60 * 60 * 1000")
      execute_script("document.dispatchEvent(new Event('visibilitychange'))")
      expected = (Time.current + 3.hours).in_time_zone("Europe/Rome")
      assert_match(/#{expected.strftime("%H:%M")}\z/, clock_text)
      assert_match(/#{expected.strftime("%a %d/%m/%Y")}/, clock_text)
    end

    it "uses the 12-hour clock when the user chose it" do
      users(:member).update!(time_format: "12h")
      visit root_path
      assert_match(/\d{1,2}:\d\d (AM|PM)\z/, clock_text)
    end

    it "is not shown on a phone or a small tablet, and is from 768 px up" do
      [320, 700].each do |width|
        page.current_window.resize_to(width, 800)
        visit root_path
        assert_no_selector "header time", visible: :visible
        assert_no_horizontal_scroll
      end
      page.current_window.resize_to(768, 800)
      visit root_path
      assert_selector "header time", visible: :visible
    end
  end
end
