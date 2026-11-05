require "application_system_test_case"

class McpTokensTest < ApplicationSystemTestCase
  it "makes a token that is shown once and then revokes it" do
    sign_in_through_form users(:member)
    visit mcp_tokens_path
    assert_selector "h1", text: I18n.t("mcp_tokens.index.title")
    click_link I18n.t("mcp_tokens.index.new")
    fill_in Core::McpToken.human_attribute_name(:name), with: "Laptop"
    check Core::McpToken.human_attribute_name(:read_only)
    click_button I18n.t("mcp_tokens.new.submit")
    assert_selector "h1", text: I18n.t("mcp_tokens.created.title")
    plain = find("#token-value").value
    assert_match(/\Aho_[0-9a-f]{64}\z/, plain)
    assert_accessible
    click_link I18n.t("mcp_tokens.created.done")
    assert_selector "li", text: "Laptop"
    assert_no_text plain
    click_button "#{I18n.t("mcp_tokens.index.revoke")} Laptop"
    within("dialog[open]") { click_button I18n.t("mcp_tokens.index.revoke_confirm") }
    assert_selector "[role=status]", text: I18n.t("mcp_tokens.destroy.revoked", name: "Laptop")
    assert_no_selector "li", text: "Laptop"
    assert_nil Core::McpToken.authenticate(plain)
  end

  it "has no axe violations on its pages, in both themes" do
    sign_in_through_form users(:member)
    %w[light dark].each do |theme|
      users(:member).update!(theme:)
      [settings_path, mcp_tokens_path, new_mcp_token_path].each do |path|
        visit path
        assert_selector "h1"
        assert_accessible
      end
    end
  end

  it "fits a 320 px screen with touch-sized targets, on every page" do
    page.current_window.resize_to(320, 640)
    sign_in_through_form users(:member)
    visit settings_path
    assert_fits_small_screen
    visit mcp_tokens_path
    assert_selector "li", text: "Writer"
    assert_fits_small_screen
    visit new_mcp_token_path
    assert_fits_small_screen
    fill_in Core::McpToken.human_attribute_name(:name), with: "Phone"
    click_button I18n.t("mcp_tokens.new.submit")
    assert_selector "h1", text: I18n.t("mcp_tokens.created.title")
    assert_fits_small_screen
  end

  it "is reached from the Settings page and leads back to it" do
    sign_in_through_form users(:member)
    visit settings_path
    click_link I18n.t("settings.show.tokens.title")
    assert_selector "h1", text: I18n.t("mcp_tokens.index.title")
    click_link I18n.t("settings.back")
    assert_selector "h1", text: I18n.t("settings.show.title")
  end

  it "copies the new token to the clipboard with a button, and says so" do
    sign_in_through_form users(:member)
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    visit new_mcp_token_path
    fill_in Core::McpToken.human_attribute_name(:name), with: "Copier"
    click_button I18n.t("mcp_tokens.new.submit")
    plain = find("#token-value").value
    click_button I18n.t("mcp_tokens.created.copy")
    assert_selector "[role=status]", text: I18n.t("mcp_tokens.created.copied")
    assert_equal plain, page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  end
end
