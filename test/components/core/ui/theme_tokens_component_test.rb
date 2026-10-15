require "test_helper"

describe Core::UI::ThemeTokensComponent do
  include ViewComponent::TestHelpers

  it "shows every color pair with its name, not by color alone" do
    render_inline(Core::UI::ThemeTokensComponent.new)
    %w[base-100 primary secondary accent neutral info success warning error].each do |token|
      assert_selector "[data-token='#{token}']", text: token
    end
    assert_selector "[data-token=primary].bg-primary.text-primary-content"
  end
end
