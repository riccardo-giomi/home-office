require "test_helper"

class McpTokensControllerTest < ActionDispatch::IntegrationTest
  let(:member) { users(:member) }

  it "needs a signed-in user" do
    get mcp_tokens_path
    assert_redirected_to new_session_path
    post mcp_tokens_path, params: {core_mcp_token: {name: "X"}}
    assert_redirected_to new_session_path
    delete mcp_token_path(core_mcp_tokens(:member_write))
    assert_redirected_to new_session_path
    assert_equal 2, member.mcp_tokens.count
  end

  describe "signed in" do
    before { sign_in_as member }

    it "lives at /settings/tokens, with a way back to the Settings page" do
      assert_equal "/settings/tokens", mcp_tokens_path
      get mcp_tokens_path
      assert_response :success
      assert_select "title", "#{I18n.t("mcp_tokens.index.title")} | Home Office"
      assert_select "h1", I18n.t("mcp_tokens.index.title")
      assert_select "h1 + p a[href='#{settings_path}']", text: I18n.t("settings.back")
    end

    it "lists only the user's tokens, with their access in words, and never a token" do
      get mcp_tokens_path
      assert_select "ol[aria-label=?] > li", I18n.t("mcp_tokens.index.caption"), 2
      assert_select "li", text: /Writer.*#{I18n.t("mcp_tokens.access.read_write")}/m
      assert_select "li", text: /Reader.*#{I18n.t("mcp_tokens.access.read_only")}/m
      assert_select "li", text: /Old laptop/, count: 0
      assert_no_match(/ho_[0-9a-f]{20}/, response.body)
      assert_no_match(core_mcp_tokens(:member_write).token_digest, response.body)
    end

    it "says when a token has not been used and when it was" do
      core_mcp_tokens(:member_read).update_columns(last_used_at: Time.utc(2026, 10, 5, 9, 30))
      get mcp_tokens_path
      assert_select "li", text: /#{I18n.t("mcp_tokens.index.last_used")}: #{I18n.t("mcp_tokens.index.never_used")}/, count: 1
      assert_select "li time[datetime='2026-10-05T09:30:00Z']"
    end

    it "explains itself when there are no tokens" do
      member.mcp_tokens.delete_all
      get mcp_tokens_path
      assert_select "ol", 0
      assert_select "p", text: I18n.t("mcp_tokens.index.empty")
      assert_select "a", text: I18n.t("mcp_tokens.index.new")
    end

    it "offers the form with a name and a read-only box, off by default" do
      get new_mcp_token_path
      assert_response :success
      assert_select "h1 + p a[href='#{mcp_tokens_path}']", text: I18n.t("mcp_tokens.back")
      assert_select "label[for=core_mcp_token_name]"
      assert_select "input#core_mcp_token_name[autocomplete=off]"
      assert_select "label[for=core_mcp_token_read_only]"
      assert_select "input[type=checkbox]#core_mcp_token_read_only:not([checked])"
    end

    it "makes a token and shows it once, on a page nothing keeps" do
      assert_difference -> { member.mcp_tokens.count }, 1 do
        post mcp_tokens_path, params: {core_mcp_token: {name: "Laptop", read_only: "1"}}
      end
      assert_response :success
      assert_match(/no-store/, response.headers["Cache-Control"])
      plain = css_select("input#token-value").first["value"]
      assert_match(/\Aho_[0-9a-f]{64}\z/, plain)
      assert_select "input#token-value[readonly]"
      assert_select "label[for=token-value]"
      assert_select "[role=status], p", text: I18n.t("mcp_tokens.created.once")
      token = Core::McpToken.authenticate(plain)
      assert_equal ["Laptop", 1, member.id], [token.name, token.read_only, token.user_id]
      get mcp_tokens_path
      assert_no_match(plain, response.body)
    end

    it "makes a read and write token when the box is left off" do
      post mcp_tokens_path, params: {core_mcp_token: {name: "Laptop", read_only: "0"}}
      assert_equal 0, member.mcp_tokens.find_by!(name: "Laptop").read_only
    end

    it "does not take other fields from the form" do
      post mcp_tokens_path, params: {core_mcp_token: {name: "Sneaky", user_id: users(:admin).id, token_digest: "e" * 64, last_used_at: "2026-01-01"}}
      token = Core::McpToken.find_by!(name: "Sneaky")
      assert_equal [member.id, nil], [token.user_id, token.last_used_at]
      refute_equal "e" * 64, token.token_digest
    end

    it "asks again, with the reasons, for a missing or a repeated name" do
      assert_no_difference -> { Core::McpToken.count } do
        post mcp_tokens_path, params: {core_mcp_token: {name: " "}}
        assert_response :unprocessable_content
        assert_select "#error-summary a[href='#core_mcp_token_name']"
        post mcp_tokens_path, params: {core_mcp_token: {name: "Writer"}}
        assert_response :unprocessable_content
        assert_select "#error-summary"
      end
    end

    it "revokes a token, which then opens nothing" do
      token = core_mcp_tokens(:member_write)
      assert_difference -> { member.mcp_tokens.count }, -1 do
        delete mcp_token_path(token)
      end
      assert_redirected_to mcp_tokens_path
      assert_equal I18n.t("mcp_tokens.destroy.revoked", name: "Writer"), flash[:notice]
      assert_nil Core::McpToken.authenticate(McpTokens::PLAIN.fetch("member_write"))
    end

    it "asks to confirm a revoke in a dialog that names the token" do
      get mcp_tokens_path
      assert_select "dialog[aria-labelledby]" do
        assert_select "form[action='#{mcp_token_path(core_mcp_tokens(:member_write))}'] input[name=_method][value=delete]"
        assert_select "p", text: /Writer/
      end
      assert_select "button[aria-haspopup=dialog]", text: /#{I18n.t("mcp_tokens.index.revoke")}/, minimum: 2
    end

    it "cannot reach another user's token: a 404, and the token stays" do
      other = core_mcp_tokens(:admin_write)
      assert_no_difference -> { Core::McpToken.count } do
        delete mcp_token_path(other)
      end
      assert_response :not_found
    end
  end
end
