require "pagy/classes/request"

class Core::UI::PaginationComponentPreview < ViewComponent::Preview
  def middle_page
    render(Core::UI::PaginationComponent.new(pagy: pagy(page: 6, count: 200), label: "Pages of results, middle"))
  end

  def first_page
    render(Core::UI::PaginationComponent.new(pagy: pagy(page: 1, count: 40), label: "Pages of results, first"))
  end

  private

  def pagy(page:, count:)
    request = Pagy::Request.new(request: {base_url: "http://example.com", path: "/results", params: {"page" => page.to_s}})
    Pagy::Offset.new(count:, page:, limit: 10, request:)
  end
end
