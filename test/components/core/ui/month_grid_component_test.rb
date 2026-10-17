require "test_helper"

describe Core::UI::MonthGridComponent do
  include ViewComponent::TestHelpers

  let(:weeks) { (Date.new(2026, 9, 27)..Date.new(2026, 10, 31)).each_slice(7).to_a }

  def grid(entries_by_day: {}, weeks: self.weeks, today: Date.new(2026, 10, 6))
    Core::UI::MonthGridComponent.new(weeks:, month: Date.new(2026, 10, 1), today:, caption: "October 2026",
      day_href: ->(date) { "/day/#{date.iso8601}" }, entries_by_day:)
  end

  def entry(title, **attrs) = {title:, href: "/e/#{title}", **attrs}

  it "is a captioned table with a header per weekday, in the order of the first row" do
    render_inline(grid)
    assert_selector "table caption", text: "October 2026", visible: :all
    assert_selector "thead th[scope=col]", count: 7
    names = I18n.t("date.day_names")
    assert_equal names, page.all("thead th", visible: :all).map { |th| th.find(".sr-only", visible: :all).text(:all) }
  end

  it "draws one row per week it is given, and a Monday-first February in four rows" do
    render_inline(grid)
    assert_selector "tbody tr", count: 5
    february = (Date.new(2027, 2, 1)..Date.new(2027, 2, 28)).each_slice(7).to_a
    render_inline(grid(weeks: february, today: Date.new(2027, 2, 2)))
    assert_selector "tbody tr", count: 4
  end

  it "links each day number to its week and marks today once" do
    render_inline(grid)
    assert_selector "td a[href='/day/2026-10-14']", text: /14/
    assert_selector "a[aria-current=date]", count: 1
    assert_selector "a[aria-current=date][href='/day/2026-10-06']"
  end

  it "lists up to three entries and links the rest to the week" do
    render_inline(grid(entries_by_day: {Date.new(2026, 10, 7) => %w[A B C D E].map { |t| entry(t) }}))
    assert_selector "td ul li", count: 3
    assert_selector "td a[href='/day/2026-10-07']", text: I18n.t("core.ui.month_grid.more", count: 2)
  end

  it "shows every entry when there are three or fewer, with no 'more' link" do
    render_inline(grid(entries_by_day: {Date.new(2026, 10, 7) => %w[A B C].map { |t| entry(t) }}))
    assert_selector "td ul li", count: 3
    assert_no_text I18n.t("core.ui.month_grid.more", count: 1)
  end

  it "gives a day with entries a count in words for narrow screens, and none without" do
    render_inline(grid(entries_by_day: {Date.new(2026, 10, 7) => [entry("A"), entry("B")]}))
    assert_selector "td .md\\:hidden", text: I18n.t("core.ui.month_grid.events", count: 2)
    assert_selector "td .md\\:hidden", count: 1
  end

  it "renders a done entry and a check from the entry hash" do
    render_inline(grid(entries_by_day: {Date.new(2026, 10, 7) => [entry("Rent", done: true, check: "<input type=checkbox id=tick>".html_safe)]}))
    assert_selector "td s", text: "Rent"
    assert_selector "td input#tick"
  end

  it "keeps the day number apart from what is under it" do
    render_inline(grid(entries_by_day: {Date.new(2026, 10, 7) => [entry("A")]}))
    assert_selector "td a.mb-1[href='/day/2026-10-07']"
  end

  it "names every day link with its full date" do
    render_inline(grid)
    assert_selector "td a .sr-only", text: I18n.l(Date.new(2026, 10, 14), format: :long), visible: :all
  end
end
