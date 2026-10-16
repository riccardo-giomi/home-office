require "test_helper"

describe "users preferences constraints" do
  let(:connection) { ActiveRecord::Base.connection }

  def insert_user(**columns)
    names = %w[email_address password_digest role created_at updated_at] + columns.keys.map(&:to_s)
    values = ["pref@example.com", "digest", "user", "2026-01-01", "2026-01-01"] + columns.values
    connection.execute("INSERT INTO users (#{names.join(", ")}) VALUES (#{values.map { |value| connection.quote(value) }.join(", ")})")
  end

  it "accepts every preference left automatic" do
    insert_user
    _(User.find_by!(email_address: "pref@example.com").locale).must_be_nil
  end

  it "accepts allowed values" do
    insert_user(locale: "it", date_format: "ymd", first_weekday: 6, time_format: "12h", time_zone: "Europe/Rome", theme: "dark")
    _(User.find_by!(email_address: "pref@example.com").first_weekday).must_equal 6
  end

  [
    [:date_format, "xyz", "chk_users_date_format"],
    [:first_weekday, 7, "chk_users_first_weekday"],
    [:first_weekday, -1, "chk_users_first_weekday"],
    [:time_format, "13h", "chk_users_time_format"],
    [:theme, "blue", "chk_users_theme"],
    [:locale, "english", "chk_users_locale_shape"],
    [:locale, "IT", "chk_users_locale_shape"]
  ].each do |column, value, constraint|
    it "rejects #{column} = #{value.inspect} with #{constraint}" do
      error = _ { insert_user(column => value) }.must_raise ActiveRecord::StatementInvalid
      _(error.message).must_match(/#{constraint}/)
    end
  end
end
