# What only items with a day and times have: the fields, the "when" row, all-day, the state buttons.
# Needs, besides SharedItemPages' definitions:
#   sample                    a timed item of admin, on 2026-10-07 at 09:30 in Europe/Rome
#   all_day_sample            an all-day item of admin
module SharedTimedItemPages
  def self.included(base)
    base.class_eval do
      def item_params(**overrides) = {param_key => {title: "Standup", day: "2026-10-09", start_time: "", end_time: "", notes: ""}.merge(overrides)}

      describe "the day and times" do
        before { sign_in_as admin }

        it "shows the time fields on the new form" do
          get new_polymorphic_path(item_class)
          assert_select "input[type=time]", 2
        end

        it "creates an all-day item" do
          post collection_path, params: item_params
          item = item_class.order(:id).last
          assert_equal [Date.new(2026, 10, 9), nil], [item.day, item.starts_at]
        end

        it "creates a timed item in the user's zone with the default end" do
          post collection_path, params: item_params(start_time: "09:30")
          item = item_class.order(:id).last
          assert_equal "Europe/Rome", item.time_zone
          assert_equal %w[09:30 10:00], [item.start_time, item.end_time]
        end

        it "keeps the typed times and answers 422 on errors" do
          post collection_path, params: item_params(title: " ", start_time: "10:00", end_time: "09:00")
          assert_response :unprocessable_content
          assert_select "input[name='#{param_key}[start_time]'][value='10:00']"
          assert_select "input[name='#{param_key}[end_time]'][value='09:00']"
        end

        it "shows the stored values in local time" do
          get edit_polymorphic_path(sample)
          assert_select "input[name='#{param_key}[start_time]'][value='#{sample.start_time}']"
          assert_select "input[name='#{param_key}[day]'][value='2026-10-07']"
        end

        it "updates the times" do
          patch polymorphic_path(sample), params: {param_key => {title: "Moved", start_time: "11:00", end_time: ""}}
          item = sample.reload
          assert_equal ["Moved", "11:00", "11:30"], [item.title, item.start_time, item.end_time]
        end

        it "makes an item all-day when both times are cleared" do
          patch polymorphic_path(sample), params: {param_key => {start_time: "", end_time: ""}}
          assert_nil sample.reload.starts_at
        end

        it "keeps the typed times when an update fails" do
          patch polymorphic_path(sample), params: {param_key => {title: "", start_time: "10:15"}}
          assert_response :unprocessable_content
          assert_select "input[name='#{param_key}[start_time]'][value='10:15']"
        end

        it "shows the day and the times in the item's own zone" do
          get polymorphic_path(sample)
          assert_select "dd time[datetime='2026-10-07']"
          assert_select "dd time[datetime='#{sample.starts_at.in_time_zone("Europe/Rome").iso8601}']"
        end

        it "says all day for an item without times" do
          get polymorphic_path(all_day_sample)
          assert_select "dd", text: /All day/
        end

        it "offers the state changes the item can have, and a reopen once it has changed" do
          get polymorphic_path(sample)
          assert_select "form[action='#{planner_item_state_path(sample)}'] button", text: copy.call("abandon")
          assert_select "form[action='#{planner_item_state_path(sample)}'] button", text: copy.call("reopen"), count: 0
          sample.update!(state: "abandoned")
          get polymorphic_path(sample)
          assert_select "form[action='#{planner_item_state_path(sample)}'] button", text: copy.call("reopen")
          assert_select "form[action='#{planner_item_state_path(sample)}'] button", text: copy.call("abandon"), count: 0
          assert_select "dd", text: "Abandoned"
        end
      end
    end
  end
end
