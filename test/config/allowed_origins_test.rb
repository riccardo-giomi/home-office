require "test_helper"
require "open3"

# config/environments/production.rb is only read in production, so each case
# boots the application that way.
describe "HOME_OFFICE_ALLOWED_ORIGINS" do
  def origins(value)
    env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "HOME_OFFICE_ALLOWED_ORIGINS" => value}
    out, status = Open3.capture2e(env, "bin/rails", "runner", "print Rails.configuration.action_cable.allowed_request_origins.inspect",
      chdir: Rails.root.to_s)
    flunk out unless status.success?
    out.lines.last
  end

  it "keeps the default check of Action Cable when it is not set or blank" do
    [nil, "", " , "].each do |value|
      _(origins(value)).must_equal "nil", "HOME_OFFICE_ALLOWED_ORIGINS=#{value.inspect}"
    end
  end

  it "accepts one origin" do
    _(origins("https://home-office.example.com:8081")).must_equal '["https://home-office.example.com:8081"]'
  end

  it "accepts several origins separated by commas, ignoring spaces" do
    _(origins("https://a.example.com, https://b.example.com")).must_equal '["https://a.example.com", "https://b.example.com"]'
  end
end
