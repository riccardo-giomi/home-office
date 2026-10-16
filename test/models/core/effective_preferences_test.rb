require "test_helper"

describe Core::EffectivePreferences do
  def prefs(attributes = {}, **options)
    Core::EffectivePreferences.new(user: User.new(attributes), **options)
  end

  describe "locale" do
    it "follows the browser when the user has no preference" do
      _(prefs(accept_language: "it-IT,it;q=0.9").locale).must_equal :it
    end

    it "prefers the stored locale to the browser" do
      _(prefs({locale: "it"}, accept_language: "en").locale).must_equal :it
    end

    it "ignores a stored locale that is no longer supported" do
      _(prefs({locale: "fr"}, accept_language: "it").locale).must_equal :it
      _(prefs({locale: "fr"}).locale).must_equal :en
    end

    it "falls back to English, also without a user" do
      _(Core::EffectivePreferences.new.locale).must_equal :en
      _(Core::EffectivePreferences.new(accept_language: "fr").locale).must_equal :en
    end
  end

  describe "formats taken from the locale" do
    it "uses US conventions for English" do
      english = prefs
      _([english.date_format, english.first_weekday, english.time_format]).must_equal ["mdy", 0, "12h"]
    end

    it "uses European conventions for Italian" do
      italian = prefs({locale: "it"})
      _([italian.date_format, italian.first_weekday, italian.time_format]).must_equal ["dmy", 1, "24h"]
    end

    it "keeps the date format independent of the language" do
      mixed = prefs({locale: "it", date_format: "mdy"})
      _([mixed.locale, mixed.date_format]).must_equal [:it, "mdy"]
    end

    it "prefers explicit choices to locale defaults" do
      explicit = prefs({locale: "it", date_format: "ymd", first_weekday: 0, time_format: "12h"})
      _([explicit.date_format, explicit.first_weekday, explicit.time_format]).must_equal ["ymd", 0, "12h"]
    end
  end

  describe "time zone" do
    it "prefers the chosen zone, then the browser's, then the detected one, then UTC" do
      _(prefs({time_zone: "Asia/Tokyo", detected_time_zone: "Europe/Rome"}, browser_time_zone: "America/New_York").time_zone).must_equal "Asia/Tokyo"
      _(prefs({detected_time_zone: "Europe/Rome"}, browser_time_zone: "America/New_York").time_zone).must_equal "America/New_York"
      _(prefs({detected_time_zone: "Europe/Rome"}).time_zone).must_equal "Europe/Rome"
      _(prefs.time_zone).must_equal "UTC"
    end

    it "works without a user, from the browser" do
      _(Core::EffectivePreferences.new(browser_time_zone: "Asia/Tokyo").time_zone).must_equal "Asia/Tokyo"
      _(Core::EffectivePreferences.new.time_zone).must_equal "UTC"
    end

    it "ignores a browser zone that is not an IANA identifier" do
      ["Mars/Base", "Rome", "../../etc/passwd", "UTC\nx", "x" * 5000, "", nil].each do |zone|
        _(prefs({detected_time_zone: "Europe/Rome"}, browser_time_zone: zone).time_zone).must_equal "Europe/Rome"
      end
    end

    it "gives jobs, which have no browser, the chosen or detected zone" do
      _(Core::EffectivePreferences.new(user: User.new(time_zone: "Asia/Tokyo")).time_zone).must_equal "Asia/Tokyo"
      _(Core::EffectivePreferences.new(user: User.new(detected_time_zone: "Europe/Rome")).time_zone).must_equal "Europe/Rome"
    end

    it "ignores a stored zone that the system no longer knows, instead of failing" do
      stale = prefs({}, browser_time_zone: "Asia/Tokyo")
      stale_user = User.new
      stale_user.time_zone = "Gone/Zone"
      stale_user.detected_time_zone = "Gone/Too"
      _(Core::EffectivePreferences.new(user: stale_user, browser_time_zone: "Asia/Tokyo").time_zone).must_equal "Asia/Tokyo"
      _(Core::EffectivePreferences.new(user: stale_user).time_zone).must_equal "UTC"
      _(stale.time_zone).must_equal "Asia/Tokyo"
    end

    it "knows which names are valid zones" do
      _(Core::EffectivePreferences.valid_time_zone?("Europe/Rome")).must_equal true
      _(Core::EffectivePreferences.valid_time_zone?("UTC")).must_equal true
      ["Rome", "Mars/Base", "", nil, 5, "\xFF\xFE".b.force_encoding("UTF-8")].each { |value| _(Core::EffectivePreferences.valid_time_zone?(value)).must_equal false }
    end
  end

  it "leaves theme automatic until the user chooses" do
    _(prefs.theme).must_be_nil
    _(prefs({theme: "dark"}).theme).must_equal "dark"
  end

  describe "theme" do
    it "follows the stored choice of a signed-in user, ignoring the cookie" do
      _(prefs({theme: "dark"}, browser_theme: "light").theme).must_equal "dark"
    end

    it "is automatic for a signed-in user without a choice, whatever the cookie says" do
      _(prefs({}, browser_theme: "dark").theme).must_be_nil
    end

    it "takes a visitor's cookie only when it is exactly light or dark" do
      _(Core::EffectivePreferences.new(browser_theme: "dark").theme).must_equal "dark"
      ['"><script>', "Dark", "dark ", "x" * 5000, "", nil, "\xFF\xFE"].each do |hostile|
        assert_nil Core::EffectivePreferences.new(browser_theme: hostile).theme, "accepted #{hostile.inspect[0, 20]}"
      end
    end
  end
end
