require "test_helper"

describe Core::UI::LinksPlaceholderComponent do
  include ViewComponent::TestHelpers

  it "is a labeled group with the heading, the sentence and what the page puts in it" do
    render_inline(Core::UI::LinksPlaceholderComponent.new(id: "links-placeholder", text: "Links need an event of their own.")) { "<button>Link</button>".html_safe }
    assert_selector "div#links-placeholder[role=group][aria-labelledby='links-placeholder-heading']"
    assert_selector "h2#links-placeholder-heading", text: I18n.t("core.ui.links_section.placeholder_heading")
    assert_text "Links need an event of their own."
    assert_selector "button", text: "Link"
  end
end
