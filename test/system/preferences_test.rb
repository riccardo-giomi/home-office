require "application_system_test_case"

class PreferencesTest < ApplicationSystemTestCase
  after do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "")
  end

  it "has no axe violations, in English and in Italian" do
    sign_in_through_form users(:member)
    visit edit_preferences_path
    assert_selector "h1", text: I18n.t("preferences.edit.title")
    assert_accessible
    users(:member).update!(locale: "it")
    visit edit_preferences_path
    assert_selector "html[lang=it]"
    assert_selector "h1", text: I18n.t("preferences.edit.title", locale: :it)
    assert_accessible
  end

  it "groups the settings, in both languages and both themes" do
    sign_in_through_form users(:member)
    [["en", "light"], ["it", "dark"]].each do |locale, theme|
      users(:member).update!(locale:, theme:)
      visit edit_preferences_path
      assert_selector "html[lang=#{locale}]"
      %w[localization day_hours theme].each { |group| assert_selector "fieldset > legend", text: I18n.t("preferences.edit.groups.#{group}", locale:) }
      assert_accessible
    end
  end

  it "fits a 320 px screen with touch-sized targets" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:member)
    visit edit_preferences_path
    assert_fits_small_screen
  end

  it "switches the language from the page" do
    sign_in_through_form users(:member)
    visit edit_preferences_path
    select "Italiano", from: User.human_attribute_name(:locale)
    click_button I18n.t("preferences.edit.submit")
    assert_selector "h1", text: I18n.t("preferences.edit.title", locale: :it)
    assert_selector "[role=status]", text: I18n.t("preferences.update.updated", locale: :it)
  end

  it "learns the browser's time zone" do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "Asia/Tokyo")
    sign_in_through_form users(:member)
    assert_equal "Asia/Tokyo", users(:member).reload.detected_time_zone
    visit edit_preferences_path
    assert_text "(Asia/Tokyo)"
  end
end
