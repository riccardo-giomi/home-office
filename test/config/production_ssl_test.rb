require "test_helper"
require "open3"

# config/environments/production.rb is only read in production, so each case boots the app that way
describe "HOME_OFFICE_SSL" do
  def settings(value)
    env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "HOME_OFFICE_SSL" => value}
    out, status = Open3.capture2e(env, "bin/rails", "runner", "print [Rails.configuration.assume_ssl, Rails.configuration.force_ssl].inspect",
      chdir: Rails.root.to_s)
    flunk out unless status.success?
    out.lines.last
  end

  it "is off unless it says true or 1, in any case" do
    {nil => "[false, false]", "0" => "[false, false]", "true" => "[true, true]", "TRUE" => "[true, true]", "1" => "[true, true]"}.each do |value, expected|
      _(settings(value)).must_equal expected, "HOME_OFFICE_SSL=#{value.inspect}"
    end
  end
end
