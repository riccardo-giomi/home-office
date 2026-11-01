# The pages every item type has (new, create, show, edit, update, delete, the dialog, going back, other users).
# What only items with a day and times have is in SharedTimedItemPages. The including test says which type it is by defining:
#   item_class, kind          the model and its lower-case name ("event", "task")
#   sample                    an item of admin
#   foreign                   an item of another user
#   default_back(item)        where "Back" goes when the visit did not begin on a listed page
module SharedItemPages
  def self.included(base)
    base.class_eval do
      let(:admin) { users(:admin) }
      let(:param_key) { item_class.model_name.param_key }
      let(:collection_path) { polymorphic_path(item_class) }
      let(:copy) { ->(key, **options) { I18n.t("planner.kinds.#{kind}.#{key}", **options) } }

      def item_params(**overrides) = {param_key => {title: "Standup", notes: ""}.merge(overrides)}

      before do
        admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
        travel_to Time.utc(2026, 10, 5, 12)
      end

      describe "creating" do
        before { sign_in_as admin }

        it "shows the form" do
          get new_polymorphic_path(item_class)
          assert_response :success
          assert_select "title", "#{copy.call("new_title")} | Home Office"
        end

        it "creates an item for the signed-in user" do
          assert_difference "item_class.count", 1 do
            post collection_path, params: item_params
          end
          item = item_class.order(:id).last
          assert_equal [admin.id, "Standup"], [item.user_id, item.title]
          assert_redirected_to default_back(item)
        end

        it "never lets the request choose the owner, the state or the zone" do
          post collection_path, params: item_params.deep_merge(param_key => {user_id: users(:other_admin).id, state: "abandoned", time_zone: "Asia/Tokyo", done_at: "2026-01-01"})
          item = item_class.order(:id).last
          assert_equal [admin.id, "active", nil, nil], [item.user_id, item.state, item.time_zone, item.done_at]
        end

        it "keeps what was typed and answers 422 on errors" do
          assert_no_difference "item_class.count" do
            post collection_path, params: item_params(title: " ", notes: "Bring the file")
          end
          assert_response :unprocessable_content
          assert_select "#error-summary"
          assert_select "textarea", text: /Bring the file/
        end
      end

      describe "creating a record linked to another" do
        let(:source) { planner_items(:pay_rent_task) }

        before { sign_in_as admin }

        it "prefills the title with the source's and carries the source in the form" do
          get new_polymorphic_path(item_class, linked_to: source.id)
          assert_response :success
          assert_select "input[name='#{param_key}[title]'][value='#{source.title}']"
          assert_select "form#item-form input[name=linked_to][value='#{source.id}']"
        end

        it "saves the record and the link together" do
          assert_difference ["item_class.count", "Core::Link.count"], 1 do
            post collection_path, params: item_params(title: "Follow up").merge(linked_to: source.id)
          end
          item = item_class.order(:id).last
          _(Core::Link.existing(admin.id, item.id, source.id)).wont_be_nil
        end

        it "saves neither, and keeps the source, when the form is invalid" do
          assert_no_difference ["item_class.count", "Core::Link.count"] do
            post collection_path, params: item_params(title: " ").merge(linked_to: source.id)
          end
          assert_response :unprocessable_content
          assert_select "form#item-form input[name=linked_to][value='#{source.id}']"
        end

        it "saves no record, and says why, when the source went to the trash after the form was drawn" do
          get new_polymorphic_path(item_class, linked_to: source.id)
          source.trash
          assert_no_difference ["item_class.count", "Core::Link.count"] do
            post collection_path, params: item_params(title: "Follow up").merge(linked_to: source.id)
          end
          assert_response :not_found
        end

        it "saves no record, and shows the reason, when the link itself is refused" do
          # refused after the source was found: it went to the trash between the lookup and the link
          original = Core::Link.method(:connect)
          Core::Link.define_singleton_method(:connect) { |user, a, b| Core::Link.new(user:, first_entity_id: a, second_entity_id: a).tap(&:validate) }
          assert_no_difference ["item_class.count", "Core::Link.count"] do
            post collection_path, params: item_params(title: "Follow up").merge(linked_to: source.id)
          end
          assert_response :unprocessable_content
          assert_select "#error-summary", text: /itself/
        ensure
          Core::Link.define_singleton_method(:connect, original)
        end

        it "answers 404, on the form and on saving, for a source that is another user's, in the trash or not there" do
          [users(:other_admin).then { planner_items(:other_users_event).id }, planner_items(:trashed_event).id, 0].each do |id|
            get new_polymorphic_path(item_class, linked_to: id)
            assert_response :not_found
            assert_no_difference ["item_class.count", "Core::Link.count"] do
              post collection_path, params: item_params(title: "Follow up").merge(linked_to: id)
            end
            assert_response :not_found
          end
        end

        it "does nothing special without a source" do
          get new_polymorphic_path(item_class)
          assert_select "input[name=linked_to]", 0
        end
      end

      describe "priority" do
        before { sign_in_as admin }

        it "offers the four levels on the new form, normal chosen" do
          get new_polymorphic_path(item_class)
          assert_select "select[name='#{param_key}[priority]'] option", 4
          assert_select "select[name='#{param_key}[priority]'] option[selected][value=normal]"
        end

        it "saves the level chosen" do
          post collection_path, params: item_params(priority: "urgent")
          assert_equal "urgent", item_class.order(:id).last.priority
        end

        it "answers 422 with an error, not a crash, for a level it does not know" do
          assert_no_difference "item_class.count" do
            post collection_path, params: item_params(priority: "9")
          end
          assert_response :unprocessable_content
          assert_select "#error-summary"
        end

        it "shows the stored level on the edit form and on the page, as a pill and a word" do
          sample.update!(priority: "high")
          get edit_polymorphic_path(sample)
          assert_select "select[name='#{param_key}[priority]'] option[selected][value=high]"
          get polymorphic_path(sample)
          assert_select "dt", text: "Priority"
          assert_select "dd span.badge[aria-label='High priority']"
          assert_select "dd", text: /High/
        end

        it "shows normal on the page too" do
          get polymorphic_path(sample)
          assert_select "dd span.badge[aria-label='Normal priority']"
          assert_select "dd", text: /Normal/
        end
      end

      describe "editing" do
        before { sign_in_as admin }

        it "updates the item" do
          patch polymorphic_path(sample), params: {param_key => {title: "Moved"}}
          item = sample.reload
          assert_equal "Moved", item.title
          assert_redirected_to polymorphic_path(item)
        end

        it "answers 422 and keeps the typed values on errors" do
          title = sample.title
          patch polymorphic_path(sample), params: {param_key => {title: "", notes: "Kept"}}
          assert_response :unprocessable_content
          assert_select "textarea", text: /Kept/
          assert_equal title, sample.reload.title
        end

        it "moves the item to the trash, and says so" do
          assert_no_difference "item_class.count" do
            assert_difference "item_class.kept.count", -1 do
              delete polymorphic_path(sample)
            end
          end
          assert_redirected_to default_back(sample)
          assert_predicate sample.reload, :trashed?
          assert_match(/trash/, flash[:notice])
        end

        it "finds nothing to delete the second time" do
          delete polymorphic_path(sample)
          delete polymorphic_path(sample)
          assert_response :not_found
        end

        it "warns on the edit page that the item goes to the trash for 30 days" do
          get edit_polymorphic_path(sample)
          assert_select "dialog p", text: /trash.*30 days/
        end
      end

      describe "showing" do
        before { sign_in_as admin }

        it "sends anonymous visitors to sign in" do
          sign_out
          get polymorphic_path(sample)
          assert_redirected_to new_session_path
        end

        it "shows the item with its notes as plain text" do
          sample.update!(notes: "Bring the X-rays\n<script>alert(1)</script>")
          get polymorphic_path(sample)
          assert_response :success
          assert_select "title", "#{copy.call("show_title", title: sample.title)} | Home Office"
          assert_select "h1", sample.title
          assert_select "dd", text: /Bring the X-rays/
          assert_select "script", text: /alert/, count: 0
          assert_match(/&lt;script&gt;/, response.body)
        end

        it "has a link to the page and view that hold it" do
          get polymorphic_path(sample)
          home = Core::Modules.linkable_kind(sample.for_links.kind).home.call(sample)
          assert_select "a[href='#{home}'][data-turbo-frame=_top]", text: /Show in/
        end

        it "shows no notes section without notes" do
          sample.update!(notes: nil)
          get polymorphic_path(sample)
          assert_select "dt", text: "Notes", count: 0
        end

        it "links back to the default page by default, and on to the edit form" do
          get polymorphic_path(sample)
          assert_select "a[href='#{default_back(sample)}']"
          assert_select "a[href='#{edit_polymorphic_path(sample)}']", text: copy.call("edit")
        end

        it "links back to the agenda or calendar page it came from, and carries that on" do
          back = planner_agenda_path(view: "week", date: "2026-10-07")
          get polymorphic_path(sample, back:)
          assert_select "a[href='#{back}']", text: "Back to agenda"
          assert_select "a[href='#{edit_polymorphic_path(sample, back:)}']", text: copy.call("edit")
          back = planner_calendar_path(view: "day", date: "2026-10-07")
          get polymorphic_path(sample, back:)
          assert_select "a[href='#{back}']", text: "Back to calendar"
        end

        it "links back to the list of forgotten tasks it came from, by its name" do
          back = "/planner/forgotten_tasks?page=2"
          get polymorphic_path(sample, back:)
          assert_response :success
          assert_select "a[href='#{back}']", text: "Back to forgotten tasks"
        end

        it "ignores a back address that is not one of our listing pages" do
          ["https://evil.example/", "//evil.example", "/admin/users", "/planner/calendar/../../session", "javascript:alert(1)", "/planner/calendar?x=<b>", "/planner/calendarx"].each do |back|
            get polymorphic_path(sample, back:)
            assert_response :success, back
            assert_select "a[href='#{default_back(sample)}']"
            assert_select "main a[href='#{back}']", count: 0
            assert_select "main a[href*='back=']", count: 0
          end
        end
      end

      describe "in the dialog" do
        before { sign_in_as admin }

        let(:frame) { {"Turbo-Frame" => "item-dialog-frame"} }

        it "answers a frame request with just the page, in the frame the dialog holds, without the way back" do
          get polymorphic_path(sample, back: planner_agenda_path), headers: frame
          assert_response :success
          assert_select "turbo-frame#item-dialog-frame h1#dialog-title", sample.title
          assert_select "nav#sidebar", count: 0
          assert_select "a", text: "Back to agenda", count: 0
          assert_select "a", text: copy.call("edit")
        end

        it "keeps the full page free of the frame, so its own forms and links behave as usual" do
          get polymorphic_path(sample)
          assert_select "turbo-frame#item-dialog-frame", count: 0
          assert_select "h1#dialog-title", sample.title
          get edit_polymorphic_path(sample)
          assert_select "turbo-frame#item-dialog-frame", count: 0
        end

        it "shows the new and edit forms in the frame, the edit form with its way back to the item" do
          get new_polymorphic_path(item_class), headers: frame
          assert_select "turbo-frame#item-dialog-frame form#item-form"
          assert_select "a", text: /\ABack to /, count: 0
          get edit_polymorphic_path(sample), headers: frame
          assert_select "turbo-frame#item-dialog-frame form#item-form"
          assert_select "a[href='#{polymorphic_path(sample)}']", text: copy.call("back_to_item")
        end

        it "answers a successful change by refreshing the page behind and closing the dialog, and says so after the refresh" do
          post collection_path, headers: frame, params: item_params
          assert_response :success
          assert_equal "text/vnd.turbo-stream.html", response.media_type
          assert_select "turbo-stream[action=refresh]:not([request-id])", 1
          assert_select "turbo-stream[action=close_dialog][target=item-dialog]", 1
          assert_equal copy.call("created"), flash[:notice]
          assert item_class.exists?(title: "Standup")
        end

        it "does the same for an update and a delete" do
          patch polymorphic_path(sample), headers: frame, params: {param_key => {title: "Renamed"}}
          assert_select "turbo-stream[action=close_dialog]", 1
          assert_equal "Renamed", sample.reload.title
          assert_equal copy.call("updated"), flash[:notice]
          delete polymorphic_path(sample), headers: frame
          assert_select "turbo-stream[action=refresh]", 1
          assert_predicate sample.reload, :trashed?
        end

        it "shows the errors inside the dialog, keeping what was typed" do
          post collection_path, headers: frame, params: item_params(title: " ", notes: "Bring the file")
          assert_response :unprocessable_content
          assert_select "turbo-frame#item-dialog-frame #error-summary"
          assert_select "textarea", text: /Bring the file/
        end

        it "keeps someone else's item out of the dialog too" do
          get polymorphic_path(foreign), headers: frame
          assert_response :not_found
        end
      end

      describe "going back after a change" do
        before { sign_in_as admin }

        let(:back) { planner_agenda_path(view: "week", date: "2026-10-07") }

        it "returns to the page the visit began on after creating or deleting, and to the item after updating" do
          post collection_path, params: item_params.merge(back:)
          assert_redirected_to back
          patch polymorphic_path(sample), params: {:back => back, param_key => {title: "Renamed"}}
          assert_redirected_to polymorphic_path(sample, back:)
          delete polymorphic_path(sample), params: {back:}
          assert_redirected_to back
        end

        it "carries the back address through a form that is shown again after errors" do
          post collection_path, params: item_params(title: " ").merge(back:)
          assert_response :unprocessable_content
          assert_select "input[type=hidden][name=back][value='#{back}']"
        end

        it "forgets an unsafe back address instead of redirecting to it" do
          delete polymorphic_path(sample), params: {back: "https://evil.example/"}
          assert_redirected_to default_back(sample)
        end
      end

      describe "someone else's item" do
        before { sign_in_as admin }

        it "is not found to show, edit, update, delete or tick" do
          title = foreign.title
          get polymorphic_path(foreign)
          assert_response :not_found
          get edit_polymorphic_path(foreign)
          assert_response :not_found
          patch polymorphic_path(foreign), params: {param_key => {title: "Mine now"}}
          assert_response :not_found
          patch planner_item_completion_path(foreign), params: {done: "1"}
          assert_response :not_found
          assert_no_difference "item_class.count" do
            delete polymorphic_path(foreign)
          end
          assert_response :not_found
          assert_equal title, foreign.reload.title
        end
      end
    end
  end
end
