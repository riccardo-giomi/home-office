require "test_helper"

describe User, "preferences" do
  let(:user) { users(:member) }

  it "has every preference automatic by default" do
    %i[locale date_format first_weekday time_format time_zone theme detected_time_zone].each do |preference|
      _(user.public_send(preference)).must_be_nil
    end
  end

  it "accepts every allowed value" do
    user.assign_attributes(locale: "it", date_format: "ymd", first_weekday: 6, time_format: "12h", time_zone: "Europe/Rome", theme: "dark", detected_time_zone: "Asia/Tokyo")
    _(user).must_be :valid?
  end

  {
    locale: "fr", date_format: "xyz", first_weekday: 7, time_format: "13h", theme: "blue",
    time_zone: "Mars/Base", detected_time_zone: "nope"
  }.each do |preference, value|
    it "rejects #{preference} = #{value.inspect}" do
      user.public_send(:"#{preference}=", value)
      _(user).wont_be :valid?
      _(user.errors[preference]).wont_be :empty?
    end
  end

  it "rejects a Rails time zone alias that is not an IANA identifier" do
    user.time_zone = "Rome"
    _(user).wont_be :valid?
  end

  it "stores a blank choice as automatic" do
    user.update!(date_format: "ymd", time_zone: "Europe/Rome")
    user.update!(date_format: "", time_zone: "", first_weekday: "")
    user.reload
    _([user.date_format, user.time_zone, user.first_weekday]).must_equal [nil, nil, nil]
  end

  describe "day hours" do
    it "are 7 and 21 until chosen" do
      user = User.new
      _([user.day_start_hour, user.day_end_hour]).must_equal [7, 21]
    end

    {day_start_hour: [24, -1, 7.5, nil], day_end_hour: [24, -1, 7.5, nil]}.each do |attribute, values|
      values.each do |value|
        it "reject #{attribute} = #{value.inspect}" do
          user.public_send(:"#{attribute}=", value)
          _(user).wont_be :valid?
          _(user.errors[attribute]).wont_be :empty?
        end
      end
    end

    it "reject an end before the start, on the end" do
      user.assign_attributes(day_start_hour: 12, day_end_hour: 10)
      _(user).wont_be :valid?
      _(user.errors[:day_end_hour]).wont_be :empty?
    end

    it "accept one single hour and the whole day" do
      user.assign_attributes(day_start_hour: 9, day_end_hour: 9)
      _(user).must_be :valid?
      user.assign_attributes(day_start_hour: 0, day_end_hour: 23)
      _(user).must_be :valid?
    end

    it "are refused by the database as well" do
      [{day_start_hour: 24}, {day_end_hour: -1}, {day_start_hour: 12, day_end_hour: 10}].each do |attributes|
        _ { user.update_columns(attributes) }.must_raise ActiveRecord::StatementInvalid
      end
    end
  end
end
