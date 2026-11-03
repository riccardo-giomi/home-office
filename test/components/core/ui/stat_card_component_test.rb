require "test_helper"

describe Core::UI::StatCardComponent do
  include ViewComponent::TestHelpers

  def lines
    [{label: "This week", count: 7, href: "/week"}, {label: "Today", count: 0, href: "/today"}, {label: "Missed events", count: 12, href: "/missed"}]
  end

  def card(**options) = render_inline(Core::UI::StatCardComponent.new(title: "Events", href: "/events", lines:, **options))

  it "is an article with the title as a link in a level 2 heading" do
    card
    assert_selector "article h2 a[href='/events']", text: "Events"
  end

  it "shows the total beside the title as text" do
    card(total: "12 in all")
    assert_selector "article h2", text: "Events"
    assert_selector "article [data-part=total]", text: "12 in all"
    assert_no_selector "a [data-part=total]"
  end

  it "has every line, a zero included, in the order given, each its own link" do
    card
    assert_selector "article ul li a", count: 3
    assert_equal ["7 This week", "0 Today", "12 Missed events"], page.all("ul li a").map { |link| link.text.squish.delete_prefix("Events: ") }
    assert_selector "ul li a[href='/today']", text: "0"
  end

  it "reads the count first in a line, as a number in a span of its own" do
    card
    assert_selector "ul li:first-child a > span[data-part=count]", text: "7"
  end

  it "is not one big link: no link wraps the lines" do
    card
    assert_no_selector "a ul, a li, a article"
    assert_selector "article > ul"
  end

  it "has two anchors for a line with a narrow link, one per breakpoint, with the same text" do
    render_inline(Core::UI::StatCardComponent.new(title: "Events", href: "/cal", narrow_href: "/agenda", lines: [{label: "This week", count: 2, href: "/cal/week", narrow_href: "/agenda/week"}]))
    assert_selector "h2 a.hidden.sm\\:inline[href='/cal']", text: "Events"
    assert_selector "h2 a.sm\\:hidden[href='/agenda']", text: "Events"
    assert_selector "li a.hidden.sm\\:block[href='/cal/week']", text: "2 This week"
    assert_selector "li a.sm\\:hidden[href='/agenda/week']", text: "2 This week"
  end

  it "has one anchor where there is no narrow link" do
    card
    assert_no_selector "a.hidden"
  end

  it "lets a very long label break instead of leaving the card" do
    render_inline(Core::UI::StatCardComponent.new(title: "T", href: "/", lines: [{label: "x" * 255, count: 1, href: "/"}]))
    assert_selector "li a.wrap-anywhere"
  end

  it "keeps the title link inline, so the total stays beside it, and the paired anchors free of a competing display class" do
    render_inline(Core::UI::StatCardComponent.new(title: "Events", href: "/cal", narrow_href: "/agenda", total: "5 in all", lines: []))
    assert_no_selector "h2 a.block"
    render_inline(Core::UI::StatCardComponent.new(title: "Todos", href: "/todos", total: "5 to do", lines: []))
    assert_no_selector "h2 a.block"
  end

  it "gives every line link the card's title as hidden context, so a link read out of its place is still clear" do
    card
    assert_selector "ul li a > span.sr-only", text: "Events:", count: 3
    assert_selector "article[aria-labelledby]"
  end

  it "gives the heading the same id every time it is drawn, so a refresh in place keeps the focus on it" do
    first = render_inline(Core::UI::StatCardComponent.new(title: "Events", href: "/events", lines: [])).css("h2").first["id"]
    second = render_inline(Core::UI::StatCardComponent.new(title: "Events", href: "/events", lines: [])).css("h2").first["id"]
    assert_equal first, second
  end
end
