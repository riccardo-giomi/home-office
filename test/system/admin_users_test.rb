require "application_system_test_case"

class AdminUsersTest < ApplicationSystemTestCase
  before { sign_in_through_form users(:admin) }

  it "has no axe violations on the list and the form" do
    visit admin_users_path
    assert_accessible
    visit new_admin_user_path
    assert_accessible
  end

  it "moves focus to the error summary and from there to the field" do
    visit new_admin_user_path
    fill_in User.human_attribute_name(:email_address), with: "new@example.com"
    fill_in User.human_attribute_name(:password), with: "short"
    fill_in User.human_attribute_name(:password_confirmation), with: "short"
    click_button I18n.t("admin.users.form.submit")
    assert_selector "#error-summary"
    assert_equal "error-summary", evaluate_script("document.activeElement.id")
    assert_accessible
    find("#error-summary a", match: :first).click
    assert_equal "user_password", evaluate_script("document.activeElement.id")
  end

  it "fits a 320 px screen on the list and the forms" do
    small_screen do
      [admin_users_path, new_admin_user_path, edit_admin_user_path(users(:member))].each do |path|
        visit path
        assert_fits_small_screen
      end
    end
  end

  it "deactivates and reactivates a user from the list, saying so in words" do
    visit admin_users_path
    within("tr", text: users(:member).email_address) { click_button "Deactivate" }
    assert_text "member@example.com deactivated."
    within("tr", text: users(:member).email_address) do
      assert_text "Deactivated"
      click_button "Reactivate"
    end
    assert_text "member@example.com reactivated."
    within("tr", text: users(:member).email_address) { assert_no_text "Deactivated" }
  end

  it "offers no deactivate button for oneself" do
    visit admin_users_path
    within("tr", text: /\Aadmin@example\.com/) { assert_no_button "Deactivate" }
  end

  %w[light dark].each do |theme|
    it "has no axe violations on the list with a deactivated user, in the #{theme} theme, and fits 320 px" do
      users(:admin).update!(theme:)
      visit admin_users_path
      assert_text "Deactivated"
      assert_accessible
      page.current_window.resize_to(320, 640)
      visit admin_users_path
      assert_fits_small_screen
    end
  end
end
