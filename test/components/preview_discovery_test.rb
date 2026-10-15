require "test_helper"

# Lookbook finds examples by reading the preview file, not by asking Ruby, so an example made with
# define_method shows on the Theme page but is missing from Lookbook's menu
describe "Lookbook discovery of previews" do
  Dir[Rails.root.join("test/components/previews/**/*_preview.rb")].each do |file|
    preview = ViewComponent::Preview.all.find { |candidate| candidate.instance_method(candidate.examples.first).source_location&.first == file if candidate.examples.any? }
    next unless preview

    it "has a plain method in #{Pathname(file).basename} for each of its examples" do
      source = File.read(file)
      missing = preview.examples.reject { |example| source.match?(/^\s*def #{Regexp.escape(example)}\b/) }
      _(missing).must_be_empty
    end
  end
end
