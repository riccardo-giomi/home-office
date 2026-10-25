require "test_helper"
require "application_system_test_case"

class Planner::CalendarSystemTest < ApplicationSystemTestCase
  include DaySliceExamples

  let(:admin) { users(:admin) }
  let(:t_) { ->(key, **options) { I18n.t("planner.calendars.show.#{key}", **options) } }

  def make_event(title, days_ahead: 0, **attrs)
    Planner::Event.create!(user: admin, title:, day: Date.current + days_ahead, **attrs)
  end

  def visit_calendar(view, **params) = visit planner_calendar_path(view:, **params)

  def visit_grid(view, **params) = visit_calendar(view, **params)

  def make_timed(title, from, to) = make_event(title, start_time: from, end_time: to)

  def active_id = evaluate_script("document.activeElement.id")

  before do
    admin.update!(time_zone: "UTC", time_format: "24h", first_weekday: 0, locale: "en")
    sign_in_through_form admin
  end

  def periods(key) = I18n.t("planner.periods.#{key}")

  it "moves between periods and views with Turbo, not full page loads" do
    make_event "Standup", start_time: "09:00", end_time: "09:30"
    visit_calendar :month
    execute_script("window.stillHere = true")
    click_link periods("next.month")
    assert_selector "header", text: I18n.l(Date.current.next_month, format: "%B %Y")
    click_link periods("previous.month")
    click_link periods("views.week")
    assert_selector "nav a[aria-current=true]", text: periods("views.week")
    click_link periods("next.week")
    click_link periods("views.day")
    assert_selector "nav a[aria-current=true]", text: periods("views.day")
    click_link periods("next.day")
    click_link I18n.t("core.ui.period_nav.today")
    assert_text "Standup"
    assert evaluate_script("window.stillHere"), "a full page load happened"
  end

  it "writes the weekday and the date with a space in the heading of today" do
    make_event "Standup"
    [planner_calendar_path(view: "day"), planner_agenda_path(view: "month")].each do |path|
      visit path
      text = evaluate_script("document.querySelector('h2[aria-current=date]').innerText")
      assert_match(%r{\A\p{L}+ \d{2}/\d{2}/\d{4}\z}, text.strip, "#{path}: #{text.inspect}")
    end
  end

  it "shows a phone the day only: the month and the week turn into the day, and the view switch is hidden" do
    page.current_window.resize_to(320, 800)
    visit_calendar :month
    assert_current_path(/view=day/)
    visit_calendar :week
    assert_current_path(/view=day/)
    assert_no_selector "nav a", text: periods("views.week")
    assert_link I18n.t("planner.calendars.show.in_agenda")
  end

  it "shows the month, the week and the day from 640 px up, with the view switch" do
    page.current_window.resize_to(640, 900)
    visit_calendar :week
    assert_current_path(/view=week/)
    %w[month week day].each { |view| assert_link periods("views.#{view}") }
  end

  it "sends a phone that rotates to a wide screen nowhere, and a wide screen narrowed to the day" do
    visit_calendar :month
    page.current_window.resize_to(320, 800)
    assert_current_path(/view=day/)
  end

  describe "where the week and the day open" do
    before { page.current_window.resize_to(1400, 700) }

    def marker_box = evaluate_script("(() => { const r = document.querySelector('[data-controller~=now-line]').getBoundingClientRect(); return {top: r.top, bottom: r.bottom, height: innerHeight} })()").transform_keys(&:to_sym)

    def scroll_room = evaluate_script("[Math.round(window.scrollY), document.documentElement.scrollHeight - innerHeight]")

    %i[week day].each do |view|
      it "shows the current time in the window, centered when there is room to center it, in the #{view} view of this period" do
        visit_calendar view, hours: "all"
        assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
        sleep 0.3
        box = marker_box
        assert_operator box[:top], :>=, 0
        assert_operator box[:bottom], :<=, box[:height]
        y, max = scroll_room
        assert_in_delta box[:height] / 2.0, box[:top], 4, "not centered (scrolled #{y} of #{max})" if y > 0 && y < max
      end

      it "stays at the top, on the navigation, in the #{view} view of a period asked for by its date" do
        visit_calendar view, date: Date.current.iso8601
        sleep 0.3
        assert_equal 0, scroll_room.first
      end
    end

    it "leaves the month at the top" do
      visit_calendar :month
      sleep 0.3
      assert_equal 0, scroll_room.first
    end

    it "stays on the navigation when moving to another period or view" do
      visit_calendar :week, hours: "all"
      sleep 0.3
      assert_operator scroll_room.first, :>, 0
      execute_script("window.scrollTo(0, 0)")
      click_link periods("next.week")
      sleep 0.3
      assert_equal 0, scroll_room.first
      click_link periods("views.day")
      sleep 0.3
      assert_equal 0, scroll_room.first
    end

    it "goes to the current time again with Today, which is the way back from the navigation" do
      visit_calendar :week, hours: "all"
      click_link periods("next.week")
      click_link I18n.t("core.ui.period_nav.today")
      assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
      sleep 0.3
      assert_operator scroll_room.first, :>, 0
      box = marker_box
      assert_operator box[:top], :>=, 0
      assert_operator box[:bottom], :<=, box[:height]
    end

    it "does not move the page again when it refreshes after a tick" do
      make_event "Pay the rent", tracks_done: 1
      visit_calendar :week
      sleep 0.3
      id = "done_item_#{Planner::Event.find_by!(title: "Pay the rent").id}"
      execute_script("window.scrollTo(0, 0)")
      before = scroll_room.first
      find("##{id}").send_keys(:space)
      assert_text I18n.t("planner.completions.update.done", title: "Pay the rent")
      sleep 0.5
      assert_equal before, scroll_room.first
    end
  end

  describe "the line for the current time" do
    def marker_top = evaluate_script("document.querySelector('[data-controller=now-line]').style.top")

    def expected_percent = Time.current.in_time_zone("UTC").then { |now| (now.hour * 60 + now.min) / 14.4 }

    %i[week day].each do |view|
      it "is drawn in today's column of the #{view} view, where the time is" do
        visit_calendar view, hours: "all"
        assert_selector "[data-controller=now-line]:not(.invisible)", visible: :all, count: 1
        assert_in_delta expected_percent, marker_top.to_f, 0.2
      end
    end

    it "moves with the clock, without the page being reloaded (time is turned back here, so midnight cannot interfere)" do
      visit_calendar :day, hours: "all"
      assert_selector "[data-controller=now-line]:not(.invisible)", visible: :all
      before = marker_top.to_f
      later = 2 * 60 * 60 * 1000
      execute_script("const real = Date.now; Date.now = () => real.call(Date) - #{later}; Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=now-line]'), 'now-line').place()")
      assert_in_delta before - (120 / 14.4), marker_top.to_f, 0.3
    end

    it "is not drawn on a month with no today, nor in a week that is not this one" do
      visit_calendar :week, date: (Date.current + 21).iso8601
      assert_no_selector "[data-controller=now-line]", visible: :all
    end
  end

  describe "where the agenda opens" do
    before do
      page.current_window.resize_to(1400, 500)
      (1..25).each { |minute| make_event "Past #{minute}", start_time: format("00:%02d", minute), end_time: format("00:%02d", minute + 1) }
      make_event "Later today", start_time: "23:58", end_time: "23:59"
    end

    def scroll_room = evaluate_script("[Math.round(window.scrollY), document.documentElement.scrollHeight - innerHeight]")

    def today_box = evaluate_script("(() => { const r = document.querySelector('[data-today] h2').getBoundingClientRect(); return {top: r.top, bottom: r.bottom, height: innerHeight} })()").transform_keys(&:to_sym)

    %w[month week day].each do |view|
      it "shows today's title at the top of the window, under the header, in the #{view} list of this period" do
        visit planner_agenda_path(view:)
        assert_selector "[data-today] h2", visible: :all
        sleep 0.3
        box = today_box
        assert_operator box[:top], :>=, 56, "the title is under the header"
        assert_operator box[:bottom], :<=, box[:height]
        # (when the list is short enough that the page cannot scroll that far, it simply is where it is)
        y, max = scroll_room
        assert_operator box[:top], :<=, 140, "title at #{box[:top]} (scrolled #{y} of #{max})" if max - y > 0
      end
    end

    it "stays at the top for a period that does not include today" do
      visit planner_agenda_path(view: "month", date: (Date.current + 62).iso8601)
      sleep 0.3
      assert_equal 0, scroll_room.first
    end

    it "stays at the top when moving to another period, and opens on today again with Today" do
      visit planner_agenda_path(view: "month")
      click_link periods("next.month")
      sleep 0.3
      assert_equal 0, scroll_room.first
      click_link I18n.t("core.ui.period_nav.today")
      assert_selector "[data-today] h2", visible: :all
      sleep 0.3
      assert_operator today_box[:top], :>=, 56
    end

    it "does not move the page again after a change is made behind or in a dialog" do
      make_event "Pay the rent", tracks_done: 1
      visit planner_agenda_path(view: "month")
      sleep 0.3
      id = "done_item_#{Planner::Event.find_by!(title: "Pay the rent").id}"
      # Selenium scrolls a field into view before typing in it: do that first, then compare the place before and after
      execute_script("document.getElementById('#{id}').scrollIntoView({block: 'start'}); window.scrollBy(0, -80)")
      # Where the box sits in the window (the browser's scroll anchoring moves scrollY when the notice appears above)
      top = -> { evaluate_script("Math.round(document.getElementById('#{id}').getBoundingClientRect().top)") }
      before = top.call
      find("##{id}").send_keys(:space)
      assert_text I18n.t("planner.completions.update.done", title: "Pay the rent")
      sleep 0.5
      assert_equal before, top.call
    end
  end

  describe "the line for the current time in the agenda" do
    before do
      make_event "Early", start_time: "00:01", end_time: "00:02"
      make_event "Late", start_time: "23:58", end_time: "23:59"
      make_event "Holiday"
    end

    # Only what this test made, in today's list: the fixtures have events around today's real date too
    def order = evaluate_script("[...document.querySelectorAll('main section li')].map(li => li.dataset.controller === 'now-divider' ? 'NOW' : (li.querySelector('a')?.innerText || '').trim()).filter(t => ['Holiday', 'Early', 'NOW', 'Late'].includes(t))")

    %w[day week month].each do |view|
      it "is in today's list of the #{view} agenda, after the all-day entries and between the two" do
        visit planner_agenda_path(view:)
        assert_equal %w[Holiday Early NOW Late], order
      end
    end

    it "moves down the list as time passes, without a reload (time is turned back here, so midnight cannot interfere)" do
      visit planner_agenda_path(view: "day")
      assert_equal %w[Holiday Early NOW Late], order
      now = Time.current.in_time_zone("UTC")
      back = ((now.hour * 60 + now.min) + 5) * 60 * 1000
      execute_script("const real = Date.now; Date.now = () => real.call(Date) - #{back}; Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=now-divider]'), 'now-divider').place()")
      assert_equal %w[Holiday NOW Early Late], order
    end
  end

  it "heads the grid from the user's first weekday" do
    admin.update!(first_weekday: 1)
    visit_calendar :month
    assert_equal I18n.t("date.abbr_day_names")[1], find("thead th:first-child span[aria-hidden]").text
  end

  %w[light dark].each do |theme|
    it "changes a navigation button's background visibly on hover in the #{theme} theme" do
      admin.update!(theme:)
      visit_calendar :month
      button = find("nav[aria-label='#{t_.call(:nav)}'] a", text: I18n.t("core.ui.period_nav.today"))
      # The browser reports oklch(); a canvas turns any CSS color into sRGB numbers
      rgb = ->(css) { evaluate_script("(c => { const x = document.createElement('canvas').getContext('2d'); x.fillStyle = c; x.fillRect(0, 0, 1, 1); return Array.from(x.getImageData(0, 0, 1, 1).data).slice(0, 3) })(#{css.to_json})") }
      resting = rgb.call(button.native.css_value("background-color"))
      page_background = rgb.call(evaluate_script("getComputedStyle(document.body).backgroundColor"))
      button.hover
      sleep 0.4 # the color change is a transition
      hovered = rgb.call(button.native.css_value("background-color"))
      assert_operator resting.zip(hovered).sum { |a, b| (a - b).abs }, :>=, 15, "hover barely changes the background: #{resting} to #{hovered}"
      assert_operator resting.zip(page_background).sum { |a, b| (a - b).abs }, :>=, 8, "the button is the page's own color: #{resting} on #{page_background}"
    end
  end

  it "puts the views on a first line and the steps on the line below, both starting at the left edge, at any width" do
    [1400, 700].each do |width|
      page.current_window.resize_to(width, 900)
      visit_calendar :month
      nav = "nav[aria-label='#{t_.call(:nav)}']"
      edges = evaluate_script("(() => { const nav = document.querySelector(\"#{nav}\"); const lines = nav.children; const views = lines[0].querySelector('ul').getBoundingClientRect(); const steps = lines[1].firstElementChild.getBoundingClientRect(); return [views.top, steps.top, views.left, steps.left, nav.getBoundingClientRect().left] })()")
      assert_operator edges[1], :>, edges[0], "at #{width} px the steps are not below the views"
      assert_in_delta edges[4], edges[2], 1, "at #{width} px the views start #{edges[2] - edges[4]}px from the left edge"
      assert_in_delta edges[4], edges[3], 1, "at #{width} px the steps start #{edges[3] - edges[4]}px from the left edge"
    end
  end

  describe "overlapping events" do
    before { %w[A B C].each { |title| make_event title, start_time: "09:00", end_time: "10:00" } }

    def boxes = evaluate_script("Array.from(document.querySelectorAll('li[class*=\"col-start\"]')).filter(l => l.querySelector('a') && /^[ABC]$/.test(l.querySelector('a').innerText) && l.getClientRects().length).map(l => { const r = l.getBoundingClientRect(); return [Math.round(r.x), Math.round(r.y), Math.round(r.width)] })")

    it "sit side by side, equally wide, from md up" do
      visit_calendar :week
      xs = boxes.map(&:first)
      assert_equal 3, xs.uniq.size, "same left edge: #{boxes.inspect}"
      assert_equal 1, boxes.map(&:last).uniq.size
      assert_equal 1, boxes.map { |box| box[1] }.uniq.size, "same top edge"
    end

    it "sit side by side in the day view of a phone too" do
      page.current_window.resize_to(320, 800)
      visit_calendar :day
      xs = boxes.map(&:first)
      assert_equal 3, xs.uniq.size, "same left edge: #{boxes.inspect}"
      assert_operator xs.max + boxes.map(&:last).max, :<=, 320
    end
  end

  describe "ticking done in place" do
    before { make_event "Pay the rent", tracks_done: 1 }

    {
      "calendar month" => -> { planner_calendar_path(view: "month") },
      "calendar week" => -> { planner_calendar_path(view: "week") },
      "calendar day" => -> { planner_calendar_path(view: "day") },
      "agenda month" => -> { planner_agenda_path(view: "month") },
      "agenda week" => -> { planner_agenda_path(view: "week") },
      "agenda day" => -> { planner_agenda_path(view: "day") }
    }.each do |name, path|
      it "keeps focus on the checkbox and stays on the #{name}" do
        visit instance_exec(&path)
        id = "done_item_#{Planner::Event.find_by!(title: "Pay the rent").id}"
        find("##{id}").send_keys(:space)
        assert_text I18n.t("planner.completions.update.done", title: "Pay the rent")
        assert_selector "s", text: "Pay the rent"
        assert_equal id, active_id
        assert_includes current_url, instance_exec(&path)
        find("##{id}").send_keys(:space)
        assert_no_selector "s", text: "Pay the rent"
      end
    end
  end

  it "keeps a long title inside its cell, its column and the screen" do
    make_event "L" * 200, start_time: "09:00", end_time: "10:00", tracks_done: 1
    [planner_calendar_path(view: "month"), planner_calendar_path(view: "week"), planner_calendar_path(view: "day"),
      planner_agenda_path(view: "month"), planner_agenda_path(view: "week"), planner_agenda_path(view: "day")].each do |path|
      visit path
      assert_no_horizontal_scroll
    end
  end

  it "fits a 320 px screen with touch-sized targets, on the calendar day and on every agenda view" do
    make_event "A very long title that has to wrap instead of pushing the page sideways", start_time: "09:00", end_time: "10:00", tracks_done: 1
    make_event "Second", start_time: "09:30", end_time: "10:30"
    page.current_window.resize_to(320, 800)
    [planner_calendar_path(view: "day"), planner_agenda_path(view: "month"), planner_agenda_path(view: "week"), planner_agenda_path(view: "day")].each do |path|
      visit path
      assert_selector "nav[aria-label]:not(#sidebar)"
      assert_fits_small_screen
    end
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme, at 1400 px and 320 px, on the calendar and the agenda" do
      admin.update!(theme:)
      make_event "Pay the rent", tracks_done: 1, done_at: Time.current
      make_event "Standup", start_time: "09:00", end_time: "09:30"
      make_event "Review", start_time: "09:15", end_time: "10:00"
      make_event "Holiday", days_ahead: 1
      6.times { |i| make_event "Crowd #{i}", days_ahead: 2, start_time: "14:00", end_time: "15:00" }
      [1400, 320].each do |width|
        page.current_window.resize_to(width, 900)
        %w[month week day].each do |view|
          visit_calendar view
          assert_selector "nav[aria-label='#{t_.call(:nav)}']"
          assert_accessible
          visit planner_agenda_path(view:)
          assert_selector "nav[aria-label='#{I18n.t("planner.agendas.show.nav")}']"
          assert_accessible
        end
      end
    end
  end
end
