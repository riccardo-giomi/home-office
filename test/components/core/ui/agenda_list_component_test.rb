require "test_helper"

describe Core::UI::AgendaListComponent do
  include ViewComponent::TestHelpers

  def entry(title, **attrs) = {title:, href: "/e/#{title}", **attrs}

  def list(days, today: Date.new(2026, 10, 6), now: nil) = Core::UI::AgendaListComponent.new(days:, today:, now:, empty_text: "Nothing this month.")

  it "lists only the days that have entries, each under a level-two heading" do
    render_inline(list([{date: Date.new(2026, 10, 7), entries: [entry("Dentist")]}, {date: Date.new(2026, 10, 8), entries: []}]))
    assert_selector "h2", count: 1
    assert_selector "h2 time[datetime='2026-10-07']"
    assert_selector "ul li", text: "Dentist", count: 1
  end

  it "keeps the order it is given, all-day entries as they come" do
    render_inline(list([{date: Date.new(2026, 10, 7), entries: [entry("First"), entry("Second")]}]))
    html = page.native.to_html
    assert_operator html.index("First"), :<, html.index("Second")
  end

  it "shows the empty text when no day has entries" do
    render_inline(list([{date: Date.new(2026, 10, 7), entries: []}]))
    assert_text "Nothing this month."
    assert_no_selector "h2"
  end

  it "marks today's heading" do
    render_inline(list([{date: Date.new(2026, 10, 6), entries: [entry("Today thing")]}]))
    assert_selector "h2[aria-current=date]"
  end

  it "puts each day in a container halfway between the page and the cards" do
    render_inline(list([{date: Date.new(2026, 10, 7), entries: [entry("A")]}, {date: Date.new(2026, 10, 8), entries: [entry("B")]}]))
    assert_selector "section.bg-base-100\\/50", count: 2
    assert_selector "section li.bg-base-100", count: 2
  end

  it "carries the done look and the check from the entry hash" do
    render_inline(list([{date: Date.new(2026, 10, 7), entries: [entry("Rent", done: true, check: "<input type=checkbox id=tick>".html_safe)]}]))
    assert_selector "s", text: "Rent"
    assert_selector "input#tick"
  end

  describe "the line for the current time" do
    let(:today) { Date.new(2026, 10, 6) }
    let(:now) { Time.utc(2026, 10, 6, 14, 35) }

    def day_of(*entries) = [{date: today, entries:}]

    def at(title, from, to) = entry(title, from:, to:)

    def titles_in_order = page.all("section li", visible: :all).map { |li| (li["data-controller"] == "now-divider") ? "NOW" : li.text.squish[/[A-Z][a-z]+\z/] }

    it "sits between the entries that have started and those still to come, after the all-day ones" do
      render_inline(list(day_of(entry("Holiday"), at("Morning", 540, 600), at("Later", 17 * 60, 18 * 60)), now:))
      assert_equal %w[Holiday Morning NOW Later], titles_in_order
    end

    it "comes first among timed entries when none has started, and last when all have" do
      render_inline(list(day_of(at("Evening", 20 * 60, 21 * 60)), now:))
      assert_equal %w[NOW Evening], titles_in_order
      render_inline(list(day_of(at("Morning", 540, 600)), now:))
      assert_equal %w[Morning NOW], titles_in_order
    end

    it "is hidden from screen readers and carries the minute of the day and the moment it was drawn" do
      render_inline(list(day_of(at("Morning", 540, 600)), now:))
      divider = page.find("[data-controller=now-divider]", visible: :all)
      assert_equal "true", divider["aria-hidden"]
      assert_equal "875", divider["data-now-divider-minutes-value"]
      assert_in_delta now.to_f * 1000, divider["data-now-divider-rendered-at-value"].to_f, 1
    end

    it "gives every timed entry its start, for the script to compare with" do
      render_inline(list(day_of(entry("Holiday"), at("Morning", 540, 600)), now:))
      assert_selector "li[data-start-minutes='540']", text: "Morning"
      assert_no_selector "li[data-start-minutes]", text: "Holiday"
    end

    it "is only in today's list, and only when a time is given" do
      render_inline(list([{date: Date.new(2026, 10, 7), entries: [at("Tomorrow", 540, 600)]}], now:))
      assert_no_selector "[data-controller=now-divider]", visible: :all
      render_inline(list(day_of(at("Morning", 540, 600))))
      assert_no_selector "[data-controller=now-divider]", visible: :all
    end
  end

  describe "the day the page opens on" do
    let(:today) { Date.new(2026, 10, 6) }
    let(:now) { Time.utc(2026, 10, 6, 14, 35) }

    def at(title, from) = entry(title, from:, to: from + 30)

    it "is today's container, whatever it holds, with a script on the list to scroll to its start once" do
      render_inline(list([{date: today - 1, entries: [at("Yesterday", 540)]}, {date: today, entries: [at("Morning", 540), at("Later", 17 * 60)]}, {date: today + 1, entries: [at("Tomorrow", 540)]}], now:))
      assert_selector "section[data-today]", count: 1
      assert_selector "section[data-today] h2[aria-current=date]"
      assert_selector "[data-controller=agenda-scroll]"
    end

    it "keeps room above it for the sticky header" do
      render_inline(list([{date: today, entries: [at("Morning", 540)]}], now:))
      assert_selector "section[data-today].scroll-mt-20"
    end

    it "is nothing when today has no entries, or when no time is given" do
      render_inline(list([{date: today + 1, entries: [at("Tomorrow", 540)]}], now:))
      assert_no_selector "section[data-today]"
      render_inline(list([{date: today, entries: [at("Morning", 540)]}]))
      assert_no_selector "section[data-today]"
      assert_no_selector "[data-controller=agenda-scroll]"
    end
  end
end
