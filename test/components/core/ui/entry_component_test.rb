require "test_helper"

describe Core::UI::EntryComponent do
  include ViewComponent::TestHelpers

  def entry(**attrs) = Core::UI::EntryComponent.new(title: "Dentist", href: "/planner/events/1/edit", **attrs)

  # The markup without the tooltip, which repeats the title and the statuses
  # before anything else.
  def markup = page.native.to_html.sub(/ title="[^"]*"/m, "")

  it "shows a timed entry's range in its own zone, next to the title link" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "Europe/Rome"))
    assert_selector "time[datetime='2026-10-07T09:30:00+02:00']", text: /\A\d{1,2}:30/
    assert_selector "time[datetime='2026-10-07T10:00:00+02:00']"
    assert_selector "a[href='/planner/events/1/edit']", text: "Dentist"
  end

  it "says all day when there are no times" do
    render_inline(entry)
    assert_no_selector "time"
    assert_text I18n.t("core.ui.entry.all_day")
  end

  it "shows a done entry struck through, with a hidden Done and not by color alone" do
    render_inline(entry(done: true))
    assert_selector "s a, a s", text: "Dentist"
    assert_selector ".sr-only", text: I18n.t("core.ui.entry.done")
  end

  it "does not mark an open entry" do
    render_inline(entry)
    assert_no_selector "s"
    assert_no_selector ".sr-only", text: I18n.t("core.ui.entry.done")
  end

  it "dims the title of a muted entry, and only of that" do
    render_inline(entry(muted: true))
    assert_selector "a.opacity-70", text: "Dentist"
    render_inline(entry)
    assert_no_selector "a.opacity-70"
  end

  it "renders the check slot before the title" do
    render_inline(entry) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
    assert_selector "input#tick"
    assert_operator markup.index("tick"), :<, markup.index("Dentist")
  end

  it "puts the title before the time when compact, so a short card clips the time first" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC", compact: true))
    html = markup
    assert_operator html.index("Dentist"), :<, html.index("<time")
  end

  it "puts the title before the time when it is not compact too" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC"))
    html = markup
    assert_operator html.index("Dentist"), :<, html.index("<time")
  end

  it "puts the check line above the title, whatever the width, so every entry has the same shape" do
    render_inline(entry) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
    assert_selector "div.relative > div.flex-nowrap input#tick"
    assert_no_selector "div.flex-wrap"
  end

  it "puts extra data on its link, for a link that opens in a dialog" do
    render_inline(entry(link_data: {turbo_frame: "event-dialog-frame"}))
    assert_selector "a[data-turbo-frame=event-dialog-frame]", text: "Dentist"
  end

  it "lets a long unbroken title wrap instead of overflowing" do
    render_inline(entry(title: "x" * 255))
    assert_selector "a.wrap-anywhere"
  end

  it "stacks its lines from the top of the card, instead of spreading them" do
    render_inline(entry)
    assert_selector "div.relative.h-full"
    assert_no_selector "div.flex-wrap"
  end

  describe "the whole entry as a link" do
    it "covers the entry with the title link, so a click anywhere opens it" do
      render_inline(entry)
      assert_selector "div.relative a.after\\:absolute.after\\:inset-0", text: "Dentist"
    end

    it "keeps the check above that link, so it can still be ticked" do
      render_inline(entry) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
      assert_selector "div.relative.z-10 input#tick"
      render_inline(entry(compact: true)) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
      assert_selector "div.relative.z-10 input#tick"
    end
  end

  describe "statuses" do
    let(:abandoned) { {icon: :minus_circle, label: "Abandoned"} }
    let(:urgent) { {priority: :urgent, label: "Urgent priority"} }
    let(:links) { {icon: :link, label: "2 links", count: 2} }

    it "draws no strip without statuses" do
      render_inline(entry)
      assert_no_selector "[role=img]"
    end

    it "puts the strip above the title, in the order given" do
      render_inline(entry(statuses: [abandoned, urgent]))
      html = markup
      assert_operator html.index("Abandoned"), :<, html.index("Urgent priority")
      assert_operator html.index("Urgent priority"), :<, html.index("Dentist")
    end

    it "says a status in words next to its icon" do
      render_inline(entry(statuses: [abandoned]))
      assert_selector "svg[aria-hidden=true]"
      assert_text "Abandoned"
    end

    it "shows an icon only, with the word as its name, in a compact entry" do
      render_inline(entry(statuses: [abandoned], compact: true))
      assert_selector "span[role=img][aria-label=Abandoned][title=Abandoned] svg"
      assert_no_text "Abandoned"
    end

    it "shows the priority as a pill named by its label, whether compact or not" do
      [false, true].each do |compact|
        render_inline(entry(statuses: [urgent], compact:))
        assert_selector "span.badge.badge-md[role=img][aria-label='Urgent priority']"
      end
    end

    it "is a container, so that its chips can follow its own width" do
      render_inline(entry)
      assert_selector "div[class~='@container']"
    end

    it "gives the word of a status only to an entry wide enough for it" do
      render_inline(entry(statuses: [abandoned]))
      assert_selector "span[role=img][aria-label=Abandoned] span.hidden[class~='@min-[14rem]:inline']", text: "Abandoned"
    end

    it "puts the number of a status that has one next to its icon, and the word when there is room" do
      render_inline(entry(statuses: [links]))
      assert_selector "span[role=img][aria-label='2 links'] span[class~='@min-[14rem]:hidden']", text: "2"
      assert_selector "span[role=img][aria-label='2 links'] span.hidden[class~='@min-[14rem]:inline']", text: "2 links"
    end

    it "shows only the number of such a status in a compact entry" do
      render_inline(entry(statuses: [links], compact: true))
      assert_selector "span[role=img][aria-label='2 links']", text: "2"
      assert_no_text "2 links"
    end

    it "keeps only the first status in a very narrow entry" do
      render_inline(entry(statuses: [abandoned, urgent]))
      assert_selector "span[class~='@max-[9rem]:hidden']", count: 1
      assert_selector "span[class~='@max-[9rem]:hidden'] span.badge"
    end

    it "keeps the check and the statuses together on one line that does not break, in a compact entry" do
      render_inline(entry(statuses: [abandoned, urgent], compact: true)) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
      assert_selector "div.flex-nowrap:has(input#tick):has(span[role=img][aria-label=Abandoned]):has(span.badge)"
    end

    it "keeps the check and the statuses together on one line that does not break, in a full entry too" do
      render_inline(entry(statuses: [abandoned, urgent])) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
      assert_selector "div.flex-nowrap:has(input#tick):has(span.badge)"
    end

    it "puts the title after that line, and the time after the title, in a compact entry" do
      render_inline(entry(statuses: [urgent], compact: true, starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC"))
      html = markup
      assert_operator html.index("Urgent priority"), :<, html.index("Dentist")
      assert_operator html.index("Dentist"), :<, html.index("<time")
    end

    it "limits a compact title to two lines, and a full one not at all" do
      render_inline(entry(compact: true))
      assert_selector "a span.line-clamp-2", text: "Dentist"
      render_inline(entry)
      assert_no_selector ".line-clamp-2"
    end
  end

  describe "the tooltip" do
    it "holds the title, the time range and the statuses, one to a line" do
      render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC", statuses: [{icon: :x_circle, label: "Cancelled"}, {priority: :urgent, label: "Urgent priority"}]))
      lines = page.find("div[title]", match: :first)[:title].split("\n")
      assert_equal "Dentist", lines.first
      assert_match(/\A\d{1,2}:30 [AP]M.\d{1,2}:00 [AP]M\z/, lines[1])
      assert_equal ["Cancelled", "Urgent priority"], lines.last(2)
    end

    it "says all day for an entry without times, and Done for a done one" do
      render_inline(entry(done: true))
      assert_equal ["Dentist", I18n.t("core.ui.entry.all_day"), I18n.t("core.ui.entry.done")], page.find("div[title]", match: :first)[:title].split("\n")
    end
  end

  describe "without a time line" do
    it "draws no time and no all-day text" do
      render_inline(entry(show_time: false))
      assert_no_text I18n.t("core.ui.entry.all_day")
      assert_selector "a", text: "Dentist"
    end

    it "still says a status in words" do
      render_inline(entry(show_time: false, statuses: [{icon: :minus_circle, label: "Abandoned"}]))
      assert_text "Abandoned"
    end
  end

  describe "commands" do
    def pin = "<button id=pin>Pin</button>".html_safe

    it "draws them at the end of the line of the statuses, above the link that covers the entry" do
      render_inline(entry(statuses: [{icon: :minus_circle, label: "Abandoned"}])) { |component| component.with_commands { pin } }
      assert_selector "div.flex-nowrap:has(span[role=img]):has(div.relative.z-10.ms-auto button#pin)"
    end

    it "draws the line for them even with no check and no status" do
      render_inline(entry) { |component| component.with_commands { pin } }
      assert_selector "div.flex-nowrap button#pin"
    end
  end
end
