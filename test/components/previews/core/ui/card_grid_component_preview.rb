class Core::UI::CardGridComponentPreview < ViewComponent::Preview
  # One module today: the grid is ready for more.
  def one_card = render(grid(["Planner"]))

  # Three cards: a column on a phone, two from 640 px, three from 1280 px.
  def three_cards = render(grid(%w[Planner Documents Expenses]))

  # A card with nothing in it still shows its counts, as zeros.
  def all_zero = render(grid(["Planner"], counts: ["0 events", "0 tasks", "0 todos"]))

  private

  def grid(titles, counts: ["12 events", "3 tasks", "1 todo"])
    Core::UI::CardGridComponent.new(label: "Trash by module").tap do |component|
      titles.each do |title|
        component.with_card { ApplicationController.render(Core::UI::CardLinkComponent.new(href: "#", title:, caption: "In the trash:", lines: counts), layout: false).html_safe }
      end
    end
  end
end
