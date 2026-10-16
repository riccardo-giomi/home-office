require "test_helper"
require "pagy/classes/request"

describe Core::UI::PaginationComponent do
  include ViewComponent::TestHelpers

  def pagy(page:, count: 60, params: {})
    request = Pagy::Request.new(request: {base_url: "http://example.com", path: "/planner/events", params: params.merge("page" => page.to_s)})
    Pagy::Offset.new(count:, page:, limit: 10, request:)
  end

  it "renders a labeled nav with the current page marked" do
    render_inline(Core::UI::PaginationComponent.new(pagy: pagy(page: 2), label: "Pages of events"))
    assert_selector "nav[aria-label='Pages of events'] a[aria-current=page]", text: "2"
    assert_selector "nav a[href*='page=3']"
  end

  it "keeps the other query parameters in its links" do
    render_inline(Core::UI::PaginationComponent.new(pagy: pagy(page: 2, params: {"when" => "past"}), label: "Pages"))
    assert_selector "nav a[href*='when=past']"
  end

  it "renders nothing for a single page" do
    render_inline(Core::UI::PaginationComponent.new(pagy: pagy(page: 1, count: 5), label: "Pages"))
    assert_no_selector "nav"
  end

  it "shows at most five page links, so it fits a 320 px screen" do
    render_inline(Core::UI::PaginationComponent.new(pagy: pagy(page: 15, count: 300), label: "Pages"))
    assert_selector "nav a[rel]:not([aria-label])", maximum: 4
    links = page.all("nav a").reject { it["aria-label"].in?(%w[Previous Next]) }
    assert_operator links.size, :<=, 5
  end
end
