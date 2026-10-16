require "test_helper"

class RequestPreferencesTest < ActionDispatch::IntegrationTest
  # The Rack::Test cookie jar percent-encodes a value once, like a browser would
  def report_zone(zone)
    cookies[:time_zone] = zone
  end

  it "follows the browser's language for an anonymous visitor" do
    get new_session_path, headers: {"Accept-Language" => "it-IT,it;q=0.9,en;q=0.8"}
    assert_select "html[lang=it]"
    assert_select "title", text: "#{I18n.t("sessions.new.title", locale: :it)} | Home Office"
  end

  it "falls back to English for unsupported or broken language headers" do
    ["fr-FR,de;q=0.8", "*", ";;;", "x" * 10_000, ";;;,it;q=0"].each do |header|
      get new_session_path, headers: {"Accept-Language" => header}
      assert_response :success
      assert_select "html[lang=en]"
    end
  end

  it "reads a good language after junk and survives header text that is not valid" do
    get new_session_path, headers: {"Accept-Language" => ";;;,;q=,it"}
    assert_select "html[lang=it]"
    get new_session_path, headers: {"Accept-Language" => "\xFF\xFE,it".b}
    assert_response :success
  end

  it "lets a stored language beat the browser's" do
    users(:member).update!(locale: "it")
    sign_in_as users(:member)
    get root_path, headers: {"Accept-Language" => "en"}
    assert_select "html[lang=it]"
  end

  it "ignores a stored language that is no longer supported" do
    users(:member).update_column(:locale, "fr")
    sign_in_as users(:member)
    get root_path
    assert_response :success
    assert_select "html[lang=en]"
  end

  it "remembers the browser's time zone on the signed-in user" do
    sign_in_as users(:member)
    report_zone "Europe/Rome"
    get root_path
    assert_equal "Europe/Rome", users(:member).reload.detected_time_zone
    report_zone "Asia/Tokyo"
    get root_path
    assert_equal "Asia/Tokyo", users(:member).reload.detected_time_zone
  end

  it "keeps a zone whose name contains a plus sign intact" do
    sign_in_as users(:member)
    report_zone "Etc/GMT+5"
    get root_path
    assert_equal "Etc/GMT+5", users(:member).reload.detected_time_zone
  end

  it "ignores time zones that are not IANA identifiers" do
    sign_in_as users(:member)
    ["Mars/Base", "Rome", "../../etc/passwd", "UTC\nSet-Cookie: x=1", "x" * 5000].each do |zone|
      report_zone zone
      get root_path
      assert_response :success
    end
    assert_nil users(:member).reload.detected_time_zone
  end

  it "survives a cookie that is not valid text" do
    sign_in_as users(:member)
    cookies[:time_zone] = "\xFF\xFE".b
    get root_path
    assert_response :success
    get new_session_path
    assert_response :success
    assert_nil users(:member).reload.detected_time_zone
  end

  it "keeps working when a stored time zone is no longer known to the system" do
    users(:member).update_columns(time_zone: "Gone/Zone", detected_time_zone: "Gone/Too")
    sign_in_as users(:member)
    get root_path
    assert_response :success
  end

  it "does not store anything for an anonymous visitor" do
    report_zone "Europe/Rome"
    assert_no_changes -> { User.pluck(:detected_time_zone) } do
      get new_session_path
    end
  end
end
