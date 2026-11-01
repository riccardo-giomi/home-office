# What the system tests of the lists of late items (Forgotten tasks, Missed
# events) have in common. The including test defines:
#
#   list_path(**params)         the path of the page
#   late_item(title, days_ago)  creates an item of admin that belongs on the list
#   clear_items                 deletes the fixtures that belong on the list
#   abandon_label               the label of the button that abandons the item in its dialog
module PagedAgendaListExamples
  def self.included(base)
    base.class_eval do
      let(:admin) { users(:admin) }

      before do
        admin.update!(time_zone: "UTC", time_format: "24h", locale: "en")
        clear_items
      end

      def tick(title) = find("input[aria-label='Done: #{title}']").click

      %w[light dark].each do |theme|
        it "has no axe violations in the #{theme} theme, with items and without" do
          admin.update!(theme:)
          sign_in_through_form admin
          visit list_path
          assert_text I18n.t("planner.#{controller_kind}.index.empty")
          assert_accessible
          late_item("Late one", 3)
          late_item("Late two", 2)
          visit list_path
          assert_text "Late one"
          assert_accessible
        end
      end

      it "fits 320 px with a title of 255 unbroken characters" do
        sign_in_through_form admin
        late_item("W" * 255, 2)
        small_screen do
          visit list_path
          assert_selector "main li a"
          assert_fits_small_screen
        end
      end

      it "keeps focus off the page's start when the first item is ticked: the page heading takes it" do
        sign_in_through_form admin
        late_item("First", 3)
        late_item("Second", 2)
        visit list_path
        tick "First"
        assert_no_selector "main li a", text: "First"
        assert_selector "main li a", text: "Second"
        assert_selector "main h1:focus"
      end

      it "shows the empty text when the last item is ticked, with focus on the heading" do
        sign_in_through_form admin
        late_item("Only one", 2)
        visit list_path
        tick "Only one"
        assert_text I18n.t("planner.#{controller_kind}.index.empty")
        assert_selector "main h1:focus"
      end

      it "drops the item and keeps focus on the heading when it is abandoned in its dialog and the dialog closes" do
        sign_in_through_form admin
        late_item("Drop me", 2)
        late_item("Keep me", 3)
        visit list_path
        click_link "Drop me"
        within("dialog[open]") { click_button abandon_label }
        assert_no_selector "main li a", text: "Drop me"
        find("dialog[open]").send_keys(:escape)
        assert_no_selector "dialog[open]"
        assert_selector "main h1:focus"
      end

      it "drops the item and keeps focus on the heading when its day is changed to today in the dialog" do
        sign_in_through_form admin
        late_item("Move me", 2)
        visit list_path
        click_link "Move me"
        click_link I18n.t("planner.kinds.#{item_kind}.edit")
        fill_in Planner::Item.human_attribute_name(:day), with: Date.current
        click_button I18n.t("planner.kinds.#{item_kind}.submit")
        assert_no_selector "dialog[open]"
        assert_text I18n.t("planner.#{controller_kind}.index.empty")
        assert_selector "main h1:focus"
      end

      it "pages with the keyboard" do
        sign_in_through_form admin
        26.times { |index| late_item(format("Item %02d", index + 1), 40 - index) }
        visit list_path
        assert_selector "main li a", text: "Item 25"
        assert_no_selector "main li a", text: "Item 26"
        find("nav[aria-label='Pages'] a", text: "2").send_keys(:enter)
        assert_selector "main li a", text: "Item 26"
        assert_no_selector "main li a", text: "Item 25"
        assert_selector "nav[aria-label='Pages'] a[aria-current=page]", text: "2"
      end
    end
  end
end
