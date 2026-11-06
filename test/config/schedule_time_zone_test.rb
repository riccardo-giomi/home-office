require "test_helper"
require "open3"

# config/environments/production.rb is only read in production, so each case
# boots the application that way.
describe "HOME_OFFICE_SCHEDULE_TIME_ZONE" do
  def boot(value)
    env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "HOME_OFFICE_SCHEDULE_TIME_ZONE" => value}
    Open3.capture2e(env, "bin/rails", "runner", "print SolidQueue.time_zone", chdir: Rails.root.to_s)
  end

  it "reads the schedules in UTC unless a time zone is given" do
    [nil, ""].each do |value|
      out, status = boot(value)
      assert status.success?, out
      _(out.lines.last).must_equal "Etc/UTC" # Solid Queue names UTC by its tzinfo identifier
    end
  end

  it "reads the schedules in the time zone that is given" do
    out, status = boot("Europe/Rome")
    assert status.success?, out
    _(out.lines.last).must_equal "Europe/Rome"
  end

  it "stops the application at boot for a name that is not a time zone" do
    out, status = boot("Mars/Olympus")
    refute status.success?
    _(out).must_match(/Invalid Timezone: Mars\/Olympus/)
  end
end
