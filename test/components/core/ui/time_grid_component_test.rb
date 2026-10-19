require "test_helper"

describe Core::UI::TimeGridComponent do
  include ViewComponent::TestHelpers

  let(:week) { (Date.new(2026, 10, 4)..Date.new(2026, 10, 10)).to_a }

  # from/to are minutes from midnight in the event's own zone; nil means all day
  def entry(title, from = nil, to = nil, **attrs) = {title:, href: "/e/#{title}", from:, to:, **attrs}

  def grid(entries = {}, today: Date.new(2026, 10, 6), now: nil)
    days = week.map { |date| {date:, entries: entries.fetch(date, [])} }
    Core::UI::TimeGridComponent.new(days:, today:, now:, agenda_href: ->(date) { "/agenda/#{date.iso8601}" })
  end

  let(:tuesday) { Date.new(2026, 10, 6) }

  it "has a level-two heading per day and marks today" do
    render_inline(grid)
    assert_selector "h2", count: 7
    assert_selector "[aria-current=date]", count: 1
    assert_selector "section:nth-of-type(3) [aria-current=date]"
  end

  it "says so, for screen readers, on a day without entries" do
    render_inline(grid)
    assert_selector "section .sr-only", text: I18n.t("core.ui.time_grid.empty"), count: 7
  end

  it "is a grid at every width: no stacked layout and no breakpoint prefixes on the placement" do
    render_inline(grid({tuesday => [entry("Dentist", 540, 600)]}))
    assert_no_selector "[class*='md:']"
  end

  it "draws one wide column for a single day, with a long heading" do
    day = {date: tuesday, entries: [entry("Dentist", 540, 600)]}
    render_inline(Core::UI::TimeGridComponent.new(days: [day], today: tuesday, agenda_href: ->(_) { "/a" }))
    assert_selector "div.grid-cols-\\[3\\.5rem_minmax\\(0\\,1fr\\)\\]"
    assert_selector "h2[aria-current=date]", text: /Tuesday/
    assert_selector "li.col-start-1.text-sm", text: "Dentist"
  end

  it "lists all-day entries before the timed ones" do
    render_inline(grid({tuesday => [entry("Timed", 540, 600), entry("Holiday")]}))
    html = page.native.to_html
    assert_operator html.index("Holiday"), :<, html.index("Timed")
    assert_selector "section ul:first-of-type li", text: "Holiday"
  end

  it "places a lone 09:00-10:00 entry on rows 37 to 40, in a cluster of one column" do
    render_inline(grid({tuesday => [entry("Dentist", 540, 600)]}))
    assert_selector "li.row-start-37.row-span-4.grid-cols-1"
    assert_selector "li.row-start-1.row-span-4.col-start-1", text: "Dentist"
  end

  it "puts three simultaneous entries in three columns of one cluster" do
    render_inline(grid({tuesday => [entry("A", 540, 600), entry("B", 540, 600), entry("C", 540, 600)]}))
    assert_selector "li.grid-cols-3", count: 1
    %w[A B C].each_with_index { |title, index| assert_selector "li.col-start-#{index + 1}", text: title }
  end

  it "sets entries of a seven-day grid in small text with little padding, so two columns still fit a word" do
    render_inline(grid({tuesday => [entry("Planning", 540, 600)]}))
    assert_selector "li.text-xs.p-0\\.5", text: "Planning"
  end

  it "packs what is drawn: neighbors whose times are off the 15-minute rows never share a cell" do
    render_inline(grid({tuesday => [entry("Long", 540, 610), entry("After", 610, 660)]}))
    assert_selector "li.grid-cols-2", count: 1
    assert_selector "li.col-start-1", text: "Long"
    assert_selector "li.col-start-2", text: "After"
  end

  it "draws an entry shorter than 30 minutes two rows tall" do
    render_inline(grid({tuesday => [entry("Quick", 600, 605)]}))
    assert_selector "li.row-start-41.row-span-2", text: "Quick"
  end

  describe "where the page scrolls to when it opens" do
    it "centers the current time when today is among the days, and the morning otherwise" do
      render_inline(grid(now: Time.utc(2026, 10, 6, 14, 35)))
      assert_selector "[data-controller~=grid-scroll][data-grid-scroll-mode-value=now]"
      render_inline(grid)
      assert_selector "[data-controller~=grid-scroll][data-grid-scroll-mode-value=morning]"
      render_inline(grid(now: Time.utc(2026, 11, 20, 9, 0), today: Date.new(2026, 11, 20)))
      assert_selector "[data-grid-scroll-mode-value=morning]"
    end

    it "labels each hour in the gutter with its number, and keeps room above them for the sticky header" do
      render_inline(grid)
      assert_selector "div[aria-hidden=true] > div[data-hour]", count: 24, visible: :all
      assert_selector "div[data-hour='7'].scroll-mt-20", visible: :all
    end
  end

  describe "the marker for the current time" do
    let(:now) { Time.utc(2026, 10, 6, 14, 35) }

    it "is a line in today's column only, hidden from screen readers and from sight until it is placed" do
      render_inline(grid(now:))
      assert_selector "[data-controller=now-marker]", count: 1
      assert_selector "section:nth-of-type(3) [data-controller=now-marker][aria-hidden=true].invisible"
    end

    it "carries the minute of the day and the moment it was drawn, for the script to move it from" do
      render_inline(grid(now:))
      marker = page.find("[data-controller=now-marker]", visible: :all)
      assert_equal "875", marker["data-now-marker-minutes-value"]
      assert_in_delta now.to_f * 1000, marker["data-now-marker-rendered-at-value"].to_f, 1
    end

    it "is not drawn when no time is given, or when today is not among the days shown" do
      render_inline(grid)
      assert_no_selector "[data-controller=now-marker]", visible: :all
      render_inline(grid(now:, today: Date.new(2026, 11, 20)))
      assert_no_selector "[data-controller=now-marker]", visible: :all
    end
  end

  it "keeps an entry that starts in the last quarter of the day inside the grid" do
    render_inline(grid({tuesday => [entry("Late", 1425, 1439)]}))
    assert_selector "li.row-start-96.row-span-1", text: "Late"
  end

  it "shows four overlapping entries and links the fifth to the agenda of its day" do
    entries = (1..5).map { |i| entry("E#{i}", 540, 600) }
    render_inline(grid({tuesday => entries}))
    assert_selector "li[class*='col-start-']", count: 4
    assert_no_text "E5"
    assert_selector "a[href='/agenda/2026-10-06']", text: I18n.t("core.ui.time_grid.more", count: 1)
  end

  it "stacks entries chronologically whatever order they come in" do
    render_inline(grid({tuesday => [entry("Later", 900, 960), entry("Earlier", 540, 600)]}))
    html = page.native.to_html
    assert_operator html.index("Earlier"), :<, html.index("Later")
  end

  it "labels the hours in a gutter that screen readers skip" do
    render_inline(grid)
    assert_selector "div[aria-hidden=true] > div", count: 24, visible: :all
  end

  it "carries the done look and the check from the entry hash" do
    render_inline(grid({tuesday => [entry("Rent", 540, 600, done: true, check: "<input type=checkbox id=tick>".html_safe)]}))
    assert_selector "s", text: "Rent"
    assert_selector "input#tick"
  end
end
