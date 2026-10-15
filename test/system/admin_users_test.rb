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
end
