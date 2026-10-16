require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  it "has no axe violations on the sign-in page" do
    visit new_session_path
    assert_selector "h1", text: I18n.t("sessions.new.title")
    assert_accessible
  end

  it "signs in with the keyboard alone" do
    visit new_session_path
    page.send_keys users(:admin).email_address, :tab, TEST_PASSWORD, :enter
    assert_selector "h1", text: I18n.t("home.show.title")
  end

  it "puts focus on the heading after signing in, without a ring around it" do
    visit new_session_path
    page.send_keys users(:admin).email_address, :tab, TEST_PASSWORD, :enter
    assert_selector "h1", text: I18n.t("home.show.title")
    assert_equal "H1", evaluate_script("document.activeElement.tagName")
    assert_equal "none", evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
  end

  it "announces a failed sign-in" do
    visit new_session_path
    fill_in I18n.t("sessions.new.email_address"), with: users(:admin).email_address
    fill_in I18n.t("sessions.new.password"), with: "wrong password here"
    click_button I18n.t("sessions.new.submit")
    assert_selector "[role=alert]", text: I18n.t("sessions.invalid")
    assert_accessible
  end

  it "fits a 320 px screen on the sign-in and home pages" do
    small_screen do
      visit new_session_path
      assert_fits_small_screen
      sign_in_through_form users(:admin)
      assert_fits_small_screen
    end
  end
end
