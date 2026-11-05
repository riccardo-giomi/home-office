require "test_helper"

# The schedules of the recurring jobs.
#
# They come from the environment: whatever is set must be something Solid Queue
# accepts.
describe "config/recurring.yml" do
  include AssertsRecurringEntry

  def purge_entry(env) = entry("purge_trash", "HOME_OFFICE_PURGE_SCHEDULE", env)

  it "purges the Planner's trash every hour unless told otherwise" do
    [nil, ""].each do |value|
      _(purge_entry(value)).must_equal({"class" => "Core::PurgeTrashJob", "schedule" => "every hour"})
    end
    _(cron?("every hour")).must_equal true
  end

  it "takes the schedule from HOME_OFFICE_PURGE_SCHEDULE" do
    _(purge_entry("every day at 3am")["schedule"]).must_equal "every day at 3am"
    _(cron?(purge_entry("every day at 3am")["schedule"])).must_equal true
    _(cron?(purge_entry("0 3 * * *")["schedule"])).must_equal true
  end

  it "reads any schedule Solid Queue accepts, including cron lines that start with a star and values with a colon" do
    ["*/5 * * * *", "* * * * *", "every day at 3am", "every day at 3:30pm", "'quoted' 0 3 * * *"].each do |value|
      _(purge_entry(value)["schedule"]).must_equal value
    end
    _(cron?(purge_entry("*/5 * * * *")["schedule"])).must_equal true
  end

  it "names a job that exists" do
    _(purge_entry(nil)["class"].constantize).must_equal Core::PurgeTrashJob
  end

  it "would be refused by Solid Queue when the value is nonsense, which is why a test looks at it" do
    _(cron?("nonsense")).must_equal false
  end

  describe "catch_up" do
    def catch_up(mode, schedule = nil) = entry("catch_up", "HOME_OFFICE_CATCH_UP_SCHEDULE", schedule, "HOME_OFFICE_CATCH_UP" => mode)

    it "is not there in lazy and off modes" do
      [nil, "lazy", "off"].each { |mode| _(catch_up(mode)).must_be_nil }
    end

    it "runs the job every hour in job mode" do
      _(catch_up("job")).must_equal({"class" => "Core::CatchUpJob", "schedule" => "every hour at minute 5"})
      _(cron?("every hour at minute 5")).must_equal true
    end

    it "takes the schedule from HOME_OFFICE_CATCH_UP_SCHEDULE" do
      _(catch_up("job", "*/30 * * * *")["schedule"]).must_equal "*/30 * * * *"
    end
  end

  describe "backup" do
    def backup(schedule = nil) = entry("backup", "HOME_OFFICE_BACKUP_SCHEDULE", schedule)

    it "runs every day at 3am unless told otherwise" do
      _(backup).must_equal({"class" => "Core::BackupJob", "schedule" => "every day at 3am"})
      _(cron?("every day at 3am")).must_equal true
    end

    it "takes the schedule from HOME_OFFICE_BACKUP_SCHEDULE" do
      _(backup("30 2 * * *")["schedule"]).must_equal "30 2 * * *"
    end
  end
end
