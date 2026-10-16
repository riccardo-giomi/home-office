require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  let(:member) { users(:member) }

  it "needs a signed-in user" do
    get edit_preferences_path
    assert_redirected_to new_session_path
    patch preferences_path, params: {user: {locale: "it"}}
    assert_redirected_to new_session_path
    assert_nil member.reload.locale
  end

  describe "signed in" do
    before { sign_in_as member }

    it "offers each preference with an automatic choice" do
      get edit_preferences_path
      assert_response :success
      assert_select "title", "#{I18n.t("preferences.edit.title")} | Home Office"
      %w[locale date_format first_weekday time_format time_zone].each do |field|
        assert_select "label[for=user_#{field}]"
        assert_select "select#user_#{field} option[value='']", text: I18n.t("preferences.automatic")
      end
      assert_select "#user_date_format_hint", text: I18n.t("preferences.edit.date_format_hint")
    end

    it "stores explicit choices" do
      patch preferences_path, params: {user: {locale: "it", date_format: "ymd", first_weekday: "1", time_format: "24h", time_zone: "Europe/Rome"}}
      assert_redirected_to edit_preferences_path
      member.reload
      _([member.locale, member.date_format, member.first_weekday, member.time_format, member.time_zone]).must_equal ["it", "ymd", 1, "24h", "Europe/Rome"]
    end

    it "stores a theme, and offers it with an automatic choice" do
      get edit_preferences_path
      assert_select "select#user_theme option[value='']", text: I18n.t("preferences.automatic")
      assert_select "select#user_theme option[value=dark]"
      patch preferences_path, params: {user: {theme: "dark"}}
      assert_equal "dark", member.reload.theme
    end

    it "stores 'automatic' as NULL, not an empty string" do
      member.update!(locale: "it", date_format: "ymd", first_weekday: 1, time_format: "24h", time_zone: "Europe/Rome")
      patch preferences_path, params: {user: {locale: "", date_format: "", first_weekday: "", time_format: "", time_zone: ""}}
      assert_redirected_to edit_preferences_path
      member.reload
      _([member.locale, member.date_format, member.first_weekday, member.time_format, member.time_zone]).must_equal [nil, nil, nil, nil, nil]
    end

    it "rejects invalid values with an error summary" do
      patch preferences_path, params: {user: {date_format: "xyz"}}
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#user_date_format']"
      assert_nil member.reload.date_format
    end

    it "never changes email, role or password through this page" do
      patch preferences_path, params: {user: {locale: "it", role: "admin", email_address: "evil@example.com", password: "a hostile new password", password_confirmation: "a hostile new password"}}
      member.reload
      _(member.locale).must_equal "it"
      _(member.role).must_equal "user"
      _(member.email_address).must_equal "member@example.com"
      assert User.authenticate_by(email_address: "member@example.com", password: TEST_PASSWORD)
    end

    it "confirms in the language just chosen" do
      patch preferences_path, params: {user: {locale: "it"}}
      follow_redirect!
      assert_select "html[lang=it]"
      assert_select "[role=status]", text: I18n.t("preferences.update.updated", locale: :it)
    end

    it "says which weekday the week starts on, also when it is automatic" do
      get edit_preferences_path
      assert_select "p", text: "Weeks start on Sunday."
      member.update!(locale: "it")
      get edit_preferences_path
      assert_select "p", text: "Primo giorno della settimana: Lunedì."
    end

    it "shows an example in the chosen zone and formats" do
      member.update!(time_zone: "Asia/Tokyo", date_format: "ymd", time_format: "24h")
      travel_to Time.utc(2026, 10, 6, 0, 30) do
        get edit_preferences_path
      end
      assert_select "time[datetime='2026-10-06T09:30:00+09:00']", text: "2026-10-06 09:30"
    end
  end
end
