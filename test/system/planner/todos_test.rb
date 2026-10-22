require "application_system_test_case"

class Planner::TodosSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  def make_todo(title, **attrs) = Planner::Todo.create!(user: admin, title:, **attrs)

  def titles = all("main ol > li a", minimum: 0).map(&:text)

  def focused_label = evaluate_script("document.activeElement.getAttribute('aria-label')")

  before do
    admin.update!(time_zone: "UTC", time_format: "24h", locale: "en")
    Planner::Todo.where(user: admin).delete_all
    sign_in_through_form admin
  end

  describe "with the buttons" do
    before { %w[First Second Third].each { |title| make_todo title } }

    it "moves a todo up, says where it went, and leaves focus on the button that was used" do
      visit planner_todos_path
      click_button "Move up: Third"
      assert_text "“Third” moved to position 2 of 3."
      assert_equal %w[First Third Second], titles
      assert_selector "button[aria-label='Move up: Third']:focus"
    end

    it "moves a todo to the top and to the bottom, with focus on the same button each time" do
      visit planner_todos_path
      click_button "Move to top: Third"
      assert_text "“Third” moved to position 1 of 3."
      assert_equal %w[Third First Second], titles
      assert_selector "button[aria-label='Move to top: Third']:focus"
      find("button[aria-label='Move to bottom: Third']").click
      assert_text "“Third” moved to position 3 of 3."
      assert_equal %w[First Second Third], titles
      assert_selector "button[aria-label='Move to bottom: Third']:focus"
    end

    it "does nothing, and keeps focus where it is, when a button at the end of the list is pressed" do
      visit planner_todos_path
      find("button[aria-label='Move up: First']").send_keys(:enter)
      assert_equal %w[First Second Third], titles
      assert_selector "button[aria-label='Move up: First']:focus"
      assert_equal "true", find("button[aria-label='Move up: First']")["aria-disabled"]
    end

    it "can be done from the keyboard alone" do
      visit planner_todos_path
      find("button[aria-label='Move down: First']").send_keys(:enter)
      assert_text "“First” moved to position 2 of 3."
      assert_equal %w[Second First Third], titles
      assert_selector "button[aria-label='Move down: First']:focus"
    end

    it "highlights the todo that moved for a moment, also when motion is reduced" do
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [{name: "prefers-reduced-motion", value: "reduce"}])
      visit planner_todos_path
      click_button "Move up: Third"
      assert_selector "li[data-controller=highlight][class~='bg-primary/20']"
      assert_no_selector "li[class~='bg-primary/20']", wait: 6
    end

    it "ticks a todo in place, with focus staying on its box" do
      visit planner_todos_path
      box = find("#done_item_#{Planner::Todo.find_by!(title: "Second").id}")
      box.send_keys(:space)
      assert_text "Marked done: Second"
      assert_selector "#done_item_#{Planner::Todo.find_by!(title: "Second").id}:focus"
      assert_selector "s", text: "Second"
    end
  end

  it "adds an urgent todo at the top, from the dialog" do
    %w[First Second].each { |title| make_todo title }
    visit planner_todos_path
    click_link "New todo"
    assert_selector "dialog[open] form#item-form"
    fill_in Planner::Todo.human_attribute_name(:title), with: "Fire"
    select "Urgent", from: Planner::Todo.human_attribute_name(:priority)
    click_button I18n.t("planner.kinds.todo.submit")
    assert_no_selector "dialog[open]"
    assert_text I18n.t("planner.kinds.todo.created")
    assert_equal %w[Fire First Second], titles
  end

  it "says so when the list is empty" do
    visit planner_todos_path
    assert_text I18n.t("planner.todos.index.empty")
  end

  describe "its pages" do
    %w[light dark].each do |theme|
      it "has no axe violations with a todo, its form and the new form open in the dialog, in the #{theme} theme" do
        admin.update!(theme:)
        make_todo "Water the plants", priority: :high, notes: "The ones on the balcony"
        visit planner_todos_path
        click_link "Water the plants"
        assert_selector "dialog[open] h1", text: "Water the plants"
        assert_selector "dialog[open] .badge[aria-label='High priority']"
        sleep 0.3
        assert_accessible(within: "#item-dialog")
        click_link I18n.t("planner.kinds.todo.edit")
        assert_selector "dialog[open] form#item-form"
        assert_no_selector "dialog[open] input[type=date]"
        assert_accessible(within: "#item-dialog")
      end
    end

    it "fits a 320 px screen on the todo's own pages" do
      todo = make_todo "Water the plants"
      page.current_window.resize_to(320, 800)
      [planner_todo_path(todo), edit_planner_todo_path(todo), new_planner_todo_path].each do |path|
        visit path
        assert_selector "h1"
        assert_fits_small_screen
      end
    end
  end

  describe "reading it" do
    it "keeps a 255-character unbroken title and the move buttons inside a 320 px screen" do
      make_todo "x" * 255
      make_todo "Short one"
      page.current_window.resize_to(320, 800)
      visit planner_todos_path
      assert_selector "main li a", text: "Short one"
      assert_fits_small_screen
    end

    %w[light dark].each do |theme|
      it "has no axe violations in the #{theme} theme, with todos of every priority, done and not, and with none" do
        admin.update!(theme:)
        make_todo "Low one", priority: :low
        make_todo "Normal one"
        make_todo("Done one", priority: :high).mark_done(true)
        Planner::Todo.find_by!(title: "Done one").tap { |todo| todo.mark_done(true) && todo.save! }
        make_todo "Urgent one", priority: :urgent
        [1400, 320].each do |width|
          page.current_window.resize_to(width, 900)
          visit planner_todos_path
          assert_selector "main li a", text: "Urgent one"
          assert_accessible
        end
        Planner::Todo.where(user: admin).delete_all
        visit planner_todos_path
        assert_text I18n.t("planner.todos.index.empty")
        assert_accessible
      end
    end
  end
end
