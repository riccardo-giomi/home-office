# What the calendar's week and day views and the schedule share: they draw the
# user's day hours first, with the hours option in the address, a switch
# between the slices and a notice for entries outside the shown hours.
#
# The including test says what is on the page by defining:
#   visit_grid(view, **params)   opens the page in :day or :week
#   make_timed(title, from, to)  creates an entry of admin today ("HH:MM" strings)
module DaySliceExamples
  def self.included(base)
    base.class_eval do
      def labeled_hours = page.all("[data-hour]", visible: :all).map { |label| label["data-hour"].to_i }

      def hours_tab(key) = I18n.t("planner.hours.#{key}")

      describe "the hours shown" do
        before { admin.update!(day_start_hour: 7, day_end_hour: 21) }

        it "are the day hours by default, in the week and in the day view" do
          %i[day week].each do |view|
            visit_grid view
            _(labeled_hours).must_equal (7..21).to_a
          end
        end

        it "can be the hours around them, with a break between, or all of them" do
          visit_grid :day, hours: "rest"
          _(labeled_hours).must_equal [0, 1, 2, 3, 4, 5, 6, 22, 23]
          assert_selector "[data-break]", visible: :all
          visit_grid :day, hours: "all"
          _(labeled_hours).must_equal (0..23).to_a
          assert_no_selector "[data-break]", visible: :all
        end

        it "are chosen with a switch that marks the current slice and keeps the date" do
          visit_grid :week
          within("ul[aria-label='#{I18n.t("planner.hours.label")}']") do
            assert_selector "a[aria-current=true]", text: hours_tab("day")
            click_link hours_tab("rest")
          end
          assert_current_path(/hours=rest/)
          assert_selector "ul[aria-label='#{I18n.t("planner.hours.label")}'] a[aria-current=true]", text: hours_tab("rest")
          click_link hours_tab("day")
          assert_no_current_path(/hours=/)
        end

        it "stay through the links of the period" do
          visit_grid :day, hours: "rest"
          click_link I18n.t("planner.periods.next.day")
          assert_current_path(/hours=rest/)
          click_link I18n.t("planner.periods.views.week")
          assert_current_path(/hours=rest/)
          click_link I18n.t("core.ui.period_nav.today")
          assert_current_path(/hours=rest/)
        end

        it "read anything unknown as the day hours" do
          visit_grid :day, hours: "everything"
          _(labeled_hours).must_equal (7..21).to_a
        end

        it "need no switch when the day hours are the whole day" do
          admin.update!(day_start_hour: 0, day_end_hour: 23)
          visit_grid :day
          _(labeled_hours).must_equal (0..23).to_a
          assert_no_selector "ul[aria-label='#{I18n.t("planner.hours.label")}']"
        end

        it "leave a note in words, with a link to where the entry is, for entries outside" do
          make_timed "Early flight", "05:00", "05:30"
          make_timed "Standup", "09:00", "09:15"
          visit_grid :day
          assert_no_text "Early flight"
          assert_text "Standup"
          link = I18n.t("core.ui.time_grid.outside.before", count: 1, time: "07:00")
          click_link link
          assert_current_path(/hours=rest/)
          assert_text "Early flight"
          assert_text "1 entry between 07:00 and 22:00"
        end

        it "follow the day hours of the user" do
          admin.update!(day_start_hour: 9, day_end_hour: 12)
          visit_grid :day
          _(labeled_hours).must_equal [9, 10, 11, 12]
        end

        it "show the line of the current time only while the clock is within them" do
          visit_grid :day
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          line_hidden = evaluate_script("document.querySelector('[data-controller~=now-line]').hidden")
          now = Time.current.in_time_zone("UTC")
          _(line_hidden).must_equal !(7..21).cover?(now.hour)
          visit_grid :day, hours: "all"
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          _(evaluate_script("document.querySelector('[data-controller~=now-line]').hidden")).must_equal false
        end

        it "put the line where the clock is among the shown hours, and hide it in the hidden ones" do
          set_clock = ->(minute) { evaluate_script(<<~JS) }
            (() => {
              const line = document.querySelector("[data-controller~=now-line]")
              const base = Number(line.dataset.nowLineRenderedAtValue) + (#{minute} - Number(line.dataset.nowLineMinutesValue)) * 60000
              Date.now = () => base
              Stimulus.getControllerForElementAndIdentifier(line, "now-line").place()
              return {hidden: line.hidden, top: line.style.top}
            })()
          JS
          visit_grid :day
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          noon = set_clock.call(12 * 60)
          _(noon["hidden"]).must_equal false
          assert_in_delta 100.0 * (12 * 60 - 7 * 60) / (15 * 60), noon["top"].to_f, 0.01
          _(set_clock.call(23 * 60)["hidden"]).must_equal true
          visit_grid :day, hours: "rest"
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          late = set_clock.call(23 * 60)
          _(late["hidden"]).must_equal false
          assert_in_delta 100.0 * (8 * 60 + 60) / (10 * 60), late["top"].to_f, 0.01
          _(set_clock.call(12 * 60)["hidden"]).must_equal true
        end

        it "keep the line of the current time when the page refreshes in place" do
          visit_grid :day, hours: "all"
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          execute_script("Turbo.session.refresh(location.href)")
          sleep 0.8
          assert_selector "[data-controller~=now-line]:not(.invisible)", visible: :all
          _(evaluate_script("document.querySelector('[data-controller~=now-line]').style.top")).wont_be :empty?
        end

        %w[light dark].each do |theme|
          it "have no axe violations in any slice, in the #{theme} theme, and fit 320 px" do
            admin.update!(theme:)
            make_timed "Early flight", "05:00", "05:30"
            make_timed "Standup", "09:00", "09:15"
            make_timed "Dinner", "22:30", "23:30"
            %w[day rest all].each do |hours|
              visit_grid :day, hours: hours
              assert_selector "[data-hour]", visible: :all
              assert_accessible
            end
            page.current_window.resize_to(320, 800)
            %w[day rest all].each do |hours|
              visit_grid :day, hours: hours
              assert_selector "[data-hour]", visible: :all
              assert_fits_small_screen
            end
          end
        end
      end
    end
  end
end
