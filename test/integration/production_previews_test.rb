require "test_helper"
require "open3"

# The Theme page renders the component previews in production, where previews are
# not enabled, so that the public preview routes do not exist. The file
# config/environments/production.rb is only read in production, so each case
# boots the application that way.
describe "component previews in production" do
  def in_production(code)
    env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1"}
    out, status = Open3.capture2e(env, "bin/rails", "runner", code, chdir: Rails.root.to_s)
    flunk out unless status.success?
    out.lines.last
  end

  it "load, together with the classes they use" do
    _(in_production("ViewComponent::Preview.all.each(&:examples); print ExampleUser.name")).must_equal "ExampleUser"
  end

  it "have no public routes" do
    code = 'print Rails.application.routes.routes.any? { |route| route.path.spec.to_s.start_with?("/rails/view_components") }'
    _(in_production(code)).must_equal "false"
  end
end
