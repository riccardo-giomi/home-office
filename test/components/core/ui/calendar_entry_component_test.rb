require "test_helper"

describe Core::UI::CalendarEntryComponent do
  include ViewComponent::TestHelpers

  def entry(**attrs) = Core::UI::CalendarEntryComponent.new(title: "Dentist", href: "/planner/events/1/edit", **attrs)

  it "shows a timed entry's range in its own zone, next to the title link" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "Europe/Rome"))
    assert_selector "time[datetime='2026-10-07T09:30:00+02:00']", text: /\A\d{1,2}:30/
    assert_selector "time[datetime='2026-10-07T10:00:00+02:00']"
    assert_selector "a[href='/planner/events/1/edit']", text: "Dentist"
  end

  it "says all day when there are no times" do
    render_inline(entry)
    assert_no_selector "time"
    assert_text I18n.t("core.ui.calendar_entry.all_day")
  end

  it "shows a done entry struck through, with a hidden Done and not by color alone" do
    render_inline(entry(done: true))
    assert_selector "s a, a s", text: "Dentist"
    assert_selector ".sr-only", text: I18n.t("core.ui.calendar_entry.done")
  end

  it "does not mark an open entry" do
    render_inline(entry)
    assert_no_selector "s"
    assert_no_selector ".sr-only", text: I18n.t("core.ui.calendar_entry.done")
  end

  it "says the state in words beside the time, and dims the title, for an abandoned or cancelled entry" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC", state_label: "Abandoned"))
    assert_text "Abandoned"
    assert_selector "a.opacity-70", text: "Dentist"
  end

  it "says the state on an all-day entry too, and shows nothing extra for an active one" do
    render_inline(entry(state_label: "Cancelled"))
    assert_text "#{I18n.t("core.ui.calendar_entry.all_day")} · Cancelled"
    render_inline(entry)
    assert_no_text "·"
    assert_no_selector "a.opacity-70"
  end

  it "renders the check slot before the title" do
    render_inline(entry) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
    assert_selector "input#tick"
    assert_operator page.native.to_html.index("tick"), :<, page.native.to_html.index("Dentist")
  end

  it "puts the title before the time when compact, so a short card clips the time first" do
    render_inline(entry(starts_at: Time.utc(2026, 10, 7, 7, 30), ends_at: Time.utc(2026, 10, 7, 8, 0), time_zone: "UTC", compact: true))
    html = page.native.to_html
    assert_operator html.index("Dentist"), :<, html.index("<time")
  end

  it "drops the check above the text when the card is too narrow for both, so the title keeps a usable width" do
    render_inline(entry) { |component| component.with_check { "<input type=checkbox id=tick>".html_safe } }
    assert_selector "div.flex.flex-wrap > div.basis-16.grow"
  end

  it "puts extra data on its link, for a link that opens in a dialog" do
    render_inline(entry(link_data: {turbo_frame: "event-dialog-frame"}))
    assert_selector "a[data-turbo-frame=event-dialog-frame]", text: "Dentist"
  end

  it "lets a long unbroken title wrap instead of overflowing" do
    render_inline(entry(title: "x" * 255))
    assert_selector "a.wrap-anywhere"
  end

  describe "priority" do
    it "shows the marker after the title" do
      render_inline(entry(priority: {level: :urgent, label: "Urgent priority"}))
      assert_selector "span.badge[role=img][aria-label='Urgent priority']"
    end

    it "shows a smaller pill in a compact entry" do
      render_inline(entry(priority: {level: :high, label: "High priority"}, compact: true))
      assert_selector "span.badge-sm[aria-label='High priority']"
    end

    it "shows nothing for a normal one" do
      render_inline(entry(priority: {level: :normal, label: "Normal"}))
      assert_no_selector "span.badge"
    end
  end

  describe "without a time line" do
    it "draws no time and no all-day text" do
      render_inline(entry(show_time: false))
      assert_no_text I18n.t("core.ui.calendar_entry.all_day")
      assert_selector "a", text: "Dentist"
    end

    it "still says the state in words" do
      render_inline(entry(show_time: false, state_label: "Abandoned"))
      assert_text "Abandoned"
    end
  end
end
