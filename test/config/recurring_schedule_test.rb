require "test_helper"
require "fugit"

# Schedule of the purge job.
#
# It comes from the environment: whatever is set must be something Solid Queue
# accepts.
describe "config/recurring.yml" do
  def entry(env)
    saved = ENV["HOME_OFFICE_PURGE_SCHEDULE"]
    env.nil? ? ENV.delete("HOME_OFFICE_PURGE_SCHEDULE") : ENV["HOME_OFFICE_PURGE_SCHEDULE"] = env
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).dig("production", "purge_trash")
  ensure
    saved.nil? ? ENV.delete("HOME_OFFICE_PURGE_SCHEDULE") : ENV["HOME_OFFICE_PURGE_SCHEDULE"] = saved
  end

  def cron?(schedule) = Fugit.parse(schedule, multi: :fail).is_a?(Fugit::Cron)

  it "purges the Planner's trash every hour unless told otherwise" do
    [nil, ""].each do |value|
      _(entry(value)).must_equal({"class" => "Core::PurgeTrashJob", "schedule" => "every hour"})
    end
    _(cron?("every hour")).must_equal true
  end

  it "takes the schedule from HOME_OFFICE_PURGE_SCHEDULE" do
    _(entry("every day at 3am")["schedule"]).must_equal "every day at 3am"
    _(cron?(entry("every day at 3am")["schedule"])).must_equal true
    _(cron?(entry("0 3 * * *")["schedule"])).must_equal true
  end

  it "reads any schedule Solid Queue accepts, including cron lines that start with a star and values with a colon" do
    ["*/5 * * * *", "* * * * *", "every day at 3am", "every day at 3:30pm", "'quoted' 0 3 * * *"].each do |value|
      _(entry(value)["schedule"]).must_equal value
    end
    _(cron?(entry("*/5 * * * *")["schedule"])).must_equal true
  end

  it "names a job that exists" do
    _(entry(nil)["class"].constantize).must_equal Core::PurgeTrashJob
  end

  it "would be refused by Solid Queue when the value is nonsense, which is why a test looks at it" do
    _(cron?("nonsense")).must_equal false
  end
end
