require "application_system_test_case"

# The previews are the components' own pages: each one, in both themes, is checked by axe, and at 320 px
# by the layout assertions. A preview is a fragment, so the rules about whole pages (one main landmark,
# a level-one heading, content inside landmarks) are left to the system tests of real pages.
class ComponentPreviewsTest < ApplicationSystemTestCase
  PAGE_RULES = %w[region landmark-one-main page-has-heading-one].freeze

  # wide_only: the app shows that component from 640 px up only (a phone gets the day view), so it is
  # not asked to fit 320 px
  def examples(small_screen: false)
    previews = ViewComponent::Preview.all.reject { |preview| small_screen && preview.try(:wide_only?) }
    previews.flat_map { |preview| preview.examples.map { |example| "/rails/view_components/#{preview.preview_name}/#{example}" } }
  end

  %w[light dark].each do |theme|
    it "has no axe violations in any preview, in the #{theme} theme" do
      examples.each do |path|
        visit "#{path}?lookbook[display][theme]=#{theme}"
        assert_selector "body"
        result = Axe::Core.new(page).call(Axe::API::Run.new.skipping(*PAGE_RULES))
        assert result.passed?, "#{path} (#{theme}): #{result.failure_message}"
      end
    end
  end

  it "fits a 320 px screen in every preview" do
    page.current_window.resize_to(320, 900)
    examples(small_screen: true).each do |path|
      visit path
      assert_selector "body"
      assert_fits_small_screen
    rescue Minitest::Assertion => error
      raise Minitest::Assertion, "#{path}: #{error.message}"
    end
  end
end
