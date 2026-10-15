require "test_helper"

# A typo in data-controller fails silently in the browser; this makes it fail here
describe "Stimulus conventions" do
  controllers = Dir[Rails.root.join("app/javascript/controllers/**/*_controller.js")].map do |path|
    Pathname(path).relative_path_from(Rails.root.join("app/javascript/controllers")).to_s.delete_suffix("_controller.js").tr("_", "-").gsub("/", "--")
  end

  it "has no leftover generator controller" do
    _(controllers).wont_include "hello"
  end

  it "has a controller file for every identifier used in templates and components" do
    used = Dir[Rails.root.join("app/{views,components}/**/*.{erb,rb}")].flat_map do |file|
      File.read(file).scan(/data-controller=["']([^"'<%]+)["']|controller: ["']([^"']+)["']/).flatten.compact.flat_map(&:split)
    end.uniq
    _(used - controllers).must_be_empty
  end
end
