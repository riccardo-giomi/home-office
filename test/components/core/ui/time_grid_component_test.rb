require "test_helper"

describe Core::UI::TimeGridComponent do
  include ViewComponent::TestHelpers

  let(:week) { (Date.new(2026, 10, 4)..Date.new(2026, 10, 10)).to_a }

  # from/to are minutes from midnight in the event's own zone; nil means all day
  def entry(title, from = nil, to = nil, **attrs) = {title:, href: "/e/#{title}", from:, to:, **attrs}

  def grid(entries = {}, today: Date.new(2026, 10, 6), now: nil, **options)
    days = week.map { |date| {date:, entries: entries.fetch(date, [])} }
    Core::UI::TimeGridComponent.new(days:, today:, now:, agenda_href: ->(date) { "/agenda/#{date.iso8601}" }, **options)
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

  it "puts the title before the time in every card of a single day, short or long" do
    day = {date: tuesday, entries: [entry("Standup", 540, 570, starts_at: Time.utc(2026, 10, 6, 9), ends_at: Time.utc(2026, 10, 6, 9, 30), time_zone: "UTC"), entry("Review", 600, 660, starts_at: Time.utc(2026, 10, 6, 10), ends_at: Time.utc(2026, 10, 6, 11), time_zone: "UTC")]}
    render_inline(Core::UI::TimeGridComponent.new(days: [day], today: tuesday, agenda_href: ->(_) { "/a" }))
    short, long = [page.find("li.rounded", text: "Standup"), page.find("li.rounded", text: "Review")].map { |card| card.native.to_html.sub(/ title="[^"]*"/m, "") }
    assert_operator short.index("Standup"), :<, short.index("<time")
    assert_operator long.index("Review"), :<, long.index("<time")
  end

  it "draws an entry shorter than 30 minutes two rows tall" do
    render_inline(grid({tuesday => [entry("Quick", 600, 605)]}))
    assert_selector "li.row-start-41.row-span-2", text: "Quick"
  end

  describe "where the page scrolls to when it opens" do
    it "centers the current time when today is among the days, and stays at the top otherwise" do
      render_inline(grid(now: Time.utc(2026, 10, 6, 14, 35)))
      assert_selector "[data-controller~=grid-scroll][data-grid-scroll-mode-value=now]"
      render_inline(grid)
      assert_selector "[data-controller~=grid-scroll][data-grid-scroll-mode-value=none]"
      render_inline(grid(now: Time.utc(2026, 11, 20, 9, 0), today: Date.new(2026, 11, 20)))
      assert_selector "[data-grid-scroll-mode-value=none]"
    end

    it "stays at the top when the caller does not allow the scroll, even with today among the days" do
      render_inline(grid(now: Time.utc(2026, 10, 6, 14, 35), scroll: false))
      assert_selector "[data-grid-scroll-mode-value=none]"
      assert_selector "[data-controller=now-line]", visible: :all
    end

    it "does not center a current time that is in hidden hours" do
      render_inline(grid(now: Time.utc(2026, 10, 6, 23, 10), segments: [420...1320]))
      assert_selector "[data-grid-scroll-mode-value=none]"
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
      assert_selector "[data-controller=now-line]", count: 1
      assert_selector "section:nth-of-type(3) [data-controller=now-line][aria-hidden=true].invisible"
    end

    it "carries the minute of the day and the moment it was drawn, for the script to move it from" do
      render_inline(grid(now:))
      marker = page.find("[data-controller=now-line]", visible: :all)
      assert_equal "875", marker["data-now-line-minutes-value"]
      assert_in_delta now.to_f * 1000, marker["data-now-line-rendered-at-value"].to_f, 1
    end

    it "is not drawn when no time is given, or when today is not among the days shown" do
      render_inline(grid)
      assert_no_selector "[data-controller=now-line]", visible: :all
      render_inline(grid(now:, today: Date.new(2026, 11, 20)))
      assert_no_selector "[data-controller=now-line]", visible: :all
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

  describe "showing only some hours" do
    let(:day_hours) { [420...1320] }
    let(:rest_hours) { [0...420, 1320...1440] }

    def hours_of(segments, entries = {}, **options) = grid(entries, segments:, **options)

    def labeled_hours = page.all("div[data-hour]", visible: :all).map { |label| label["data-hour"].to_i }

    it "labels only the hours of the stretch, and is as tall as they are" do
      render_inline(hours_of(day_hours))
      _(labeled_hours).must_equal((7..21).to_a)
      assert_selector "ul.row-span-60"
      assert_selector "div.col-start-1.row-span-60", visible: :all
    end

    it "clips an entry that crosses the first edge, keeping its full times in the text" do
      entry = entry("Early", 390, 450, starts_at: Time.utc(2026, 10, 6, 6, 30), ends_at: Time.utc(2026, 10, 6, 7, 30), time_zone: "UTC")
      render_inline(hours_of(day_hours, {tuesday => [entry]}))
      assert_selector "li.row-start-1.row-span-2", text: "Early"
      assert_text "6:30"
      assert_text "7:30"
    end

    it "clips an entry that crosses the last edge" do
      render_inline(hours_of(day_hours, {tuesday => [entry("Late", 1290, 1380)]}))
      assert_selector "li.row-start-1.row-span-2", text: "Late"
    end

    it "does not draw an entry wholly outside, and says how many in words, once" do
      entries = [entry("Dawn", 300, 360), entry("Night", 1320, 1380), entry("Night two", 1350, 1400), entry("Noon", 720, 780)]
      render_inline(hours_of(day_hours, {tuesday => entries}))
      assert_no_text "Dawn"
      assert_no_text "Night"
      assert_selector "li", text: "Noon"
      assert_selector "li[data-outside=before]", text: I18n.t("core.ui.time_grid.outside.before", count: 1, time: "7:00 AM")
      assert_selector "li[data-outside=after]", text: I18n.t("core.ui.time_grid.outside.after", count: 2, time: "10:00 PM")
    end

    it "links the notice to the other hours of that day when it is told where" do
      render_inline(hours_of(day_hours, {tuesday => [entry("Dawn", 300, 360)]}, outside_href: ->(date) { "/hours/#{date.iso8601}" }))
      assert_selector "li[data-outside=before] a[href='/hours/2026-10-06']"
      render_inline(hours_of(day_hours, {tuesday => [entry("Dawn", 300, 360)]}))
      assert_selector "li[data-outside=before]"
      assert_no_selector "li[data-outside=before] a"
    end

    it "keeps the edges exact: ending when the hours start, starting when they end, a point in time" do
      entries = [entry("Ends at seven", 360, 420), entry("Starts at ten pm", 1320, 1380), entry("Point at seven", 420, 420), entry("Point at ten pm", 1320, 1320)]
      render_inline(hours_of(day_hours, {tuesday => entries}))
      assert_no_text "Ends at seven"
      assert_no_text "Starts at ten pm"
      assert_selector "li", text: "Point at seven"
      assert_no_text "Point at ten pm"
      assert_selector "li[data-outside=before]", text: /\A\s*1 /
      assert_selector "li[data-outside=after]", text: /\A\s*2 /
    end

    it "does not count all-day entries as outside" do
      render_inline(hours_of(day_hours, {tuesday => [entry("Holiday")]}))
      assert_no_selector "li[data-outside]"
      assert_text "Holiday"
    end

    it "draws the hours around the day hours as two stretches with a break between" do
      render_inline(hours_of(rest_hours))
      _(labeled_hours).must_equal [0, 1, 2, 3, 4, 5, 6, 22, 23]
      assert_selector "div[aria-hidden=true] > div[data-break]", count: 1, visible: :all
      assert_selector "ul > li[data-break].row-start-29.row-span-4", count: 7, visible: :all
      assert_selector "ul.row-span-40"
    end

    it "places the second stretch after the break" do
      render_inline(hours_of(rest_hours, {tuesday => [entry("Night", 1320, 1380)]}))
      assert_selector "li.row-start-1.row-span-4.col-start-1", text: "Night"
      assert_selector "li.row-start-33", visible: :all
    end

    it "lets an entry that spans the hidden middle cover the break" do
      render_inline(hours_of(rest_hours, {tuesday => [entry("All day long", 300, 1400)]}))
      assert_selector "li.row-start-1.row-span-18", text: "All day long"
    end

    it "counts what is in the hidden middle as between" do
      render_inline(hours_of(rest_hours, {tuesday => [entry("Lunch", 720, 780)]}))
      assert_selector "li[data-outside=between]", text: I18n.t("core.ui.time_grid.outside.between", count: 1, from: "7:00 AM", to: "10:00 PM")
      assert_no_text "Lunch"
    end

    it "draws one stretch without a break when the other would be empty" do
      render_inline(hours_of([1320...1440]))
      assert_no_selector "[data-break]", visible: :all
      _(labeled_hours).must_equal [22, 23]
    end

    it "joins stretches that touch, without a break" do
      render_inline(hours_of([0...600, 600...1440]))
      assert_no_selector "[data-break]", visible: :all
      _(labeled_hours.size).must_equal 24
    end

    it "draws the whole day for no stretches at all" do
      render_inline(hours_of([]))
      _(labeled_hours.size).must_equal 24
    end

    it "gives the line the stretches, so the script can follow the clock through them" do
      render_inline(hours_of(rest_hours, now: Time.utc(2026, 10, 6, 14, 35)))
      marker = page.find("[data-controller=now-line]", visible: :all)
      assert_equal [[0, 420, 0], [1320, 1440, 480]], JSON.parse(marker["data-now-line-segments-value"])
      assert_equal "600", marker["data-now-line-total-value"]
      assert_equal "875", marker["data-now-line-minutes-value"]
    end
  end
end
